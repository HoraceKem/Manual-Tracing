% VastTools.m
% Additional tools for VAST in Matlab
% Version 1.2.1 by Daniel Berger, August 2014 - November 15 2018

function [] = vasttools()
  global vdata;
  if isfield(vdata,'state')
    warndlg('VastTools is already running. Close other instance. If necessary use "clear -global vdata" to fix.','Error starting VastTools');
    return;
  end;
  
  p = mfilename('fullpath');
  p = p(1:end-size(mfilename(),2));
  thispath=p;
  addpath(p);
  addpath([p 'VASTControl/']);
  vast=VASTControlClass();  %CAUTION: This contains javaaddpath which clears all globals. WTF, Matlab !

  global vdata;
  vdata.vast=vast;
  vdata.state.isconnected=0;
  vdata.state.connect.ip='127.0.0.1';
  vdata.state.connect.port=22081;
  vdata.state.lastcancel=1;
  vdata.state.guiblocked=0; 
  vdata.data.nroftargetlists=0;
  vdata.data.nrofsimplenavigators=0;
  vdata.etfh=[];
  vdata.msfh=[];
  
  scrsz = get(0,'ScreenSize');
  vdata.fh = figure('units','pixels',...
    'outerposition',[10 scrsz(4)-639-10 640 200],...
    'menubar','none',...
    'numbertitle','off',...
    'name','VastTools Version 1.2.1 (c) November 15th 2018 by Daniel Berger');

  set(vdata.fh,'CloseRequestFcn',{@callback_quit});
  set(vdata.fh,'ResizeFcn',{@callback_resize},'resize','on');
  
    %%%%%% MAIN MENU %%%%%%%
  
  vdata.ui.menu.connectmenu = uimenu(vdata.fh,'Label','Connect');
  vdata.ui.menu.connectvast = uimenu(vdata.ui.menu.connectmenu,'Label','Connect to VAST','Callback',{@callback_connect});
  
  vdata.ui.connectoptions = uimenu(vdata.ui.menu.connectmenu,'Label','Connection Options','Callback',{@callback_connectionoptions});
  vdata.ui.quit = uimenu(vdata.ui.menu.connectmenu,'Label','Quit','Callback',{@callback_quit},'Separator','on','Accelerator','Q');
  vdata.ui.menu.exportmenu = uimenu(vdata.fh,'Label','Export');
  vdata.ui.menu.exportobj = uimenu(vdata.ui.menu.exportmenu,'Label','Export 3D Objects as OBJ Files ...','Callback',{@callback_exportobj},'Enable','off');
  vdata.ui.menu.exportparticles = uimenu(vdata.ui.menu.exportmenu,'Label','Export Particle Clouds (3D Object Instancing) ...','Callback',{@callback_exportparticles},'Enable','off');
  vdata.ui.menu.exportbox = uimenu(vdata.ui.menu.exportmenu,'Label','Export 3D Box ...','Callback',{@callback_exportbox},'Enable','off');
  vdata.ui.menu.exportscalebar = uimenu(vdata.ui.menu.exportmenu,'Label','Export 3D Scale Bar ...','Callback',{@callback_exportscalebar},'Enable','off');
  vdata.ui.menu.exportprojection = uimenu(vdata.ui.menu.exportmenu,'Label','Export Projection Image ...','Callback',{@callback_exportprojection},'Enable','off');
  vdata.ui.menu.measuremenu = uimenu(vdata.fh,'Label','Measure');
  vdata.ui.menu.measurevolumes = uimenu(vdata.ui.menu.measuremenu,'Label','Measure Segment Volumes ...','Callback',{@callback_measurevol},'Enable','off');
  vdata.ui.menu.measurelengths = uimenu(vdata.ui.menu.measuremenu,'Label','Measure Segment Lengths ...','Callback',{@callback_measurelength},'Enable','off');
  vdata.ui.menu.euclidiantool = uimenu(vdata.ui.menu.measuremenu,'Label','Euclidian Distance Measurement Tool','Callback',{@callback_euclidiantool},'Enable','off');
  vdata.ui.menu.navigatemenu = uimenu(vdata.fh,'Label','Navigate');
  vdata.ui.menu.newsimplenavigator = uimenu(vdata.ui.menu.navigatemenu,'Label','New Simple Navigator Image From Last Projection Image ...','Callback',{@callback_newsimplenavigator});
  vdata.ui.menu.loadsimplenavigator = uimenu(vdata.ui.menu.navigatemenu,'Label','Load Simple Navigator Image From File ...','Callback',{@callback_loadsimplenavigator});
  vdata.ui.menu.targetlistmenu = uimenu(vdata.fh,'Label','Target List');
  vdata.ui.menu.newtargetlist = uimenu(vdata.ui.menu.targetlistmenu,'Label','New Target List ...','Callback',{@callback_newtargetlist});
  vdata.ui.menu.loadtargetlist = uimenu(vdata.ui.menu.targetlistmenu,'Label','Load Target List ...','Callback',{@callback_loadtargetlist});

  pos=get(vdata.fh,'Position');
  vdata.ui.cancelbutton = uicontrol('style','push','units','pixels','position',[12 pos(4)-62 55 25],...
    'string','Cancel','Enable','off','callback',{@callback_canceled});
  vdata.ui.message = uicontrol('style','text','unit','pix','position',[85 pos(4)-110 pos(3)-10 100],'fontsize',11,'string','Idle','backgroundcolor',[0.75 0.75 0.65]);
  set(vdata.ui.message,'String',{'DISCLAIMER', 'VastTools is provided as-is. You are using the functions herein, especially the functions for measurement and analysis, at your own risk. This software may contain bugs and produce wrong results. Please make sure your data set is scaled correctly in VAST (check Info / Volume Properties). In case you encounter any bugs, please let me know.'});
  pause(0.1);
  callback_resize();
  
function [] = callback_quit(varargin)
  global vdata;
  
  %Check if there are unsaved target lists
  if (vdata.data.nroftargetlists>0)
    changedtlexists=0;
    
    for instance=1:1:vdata.data.nroftargetlists
      if ishandle(vdata.data.tl(instance).fh)
        if (vdata.data.tl(instance).ischanged==1)
          changedtlexists=changedtlexists+1;
        end;
      end;
    end;

    if (changedtlexists==1)
      res = questdlg('You have a changed target list open. Are you sure you want to quit without saving?','Quit VastTools','Yes','No','Yes');
      if strcmp(res,'No')
        return;
      end
    end;
    if (changedtlexists>1)
      res = questdlg('You have changed target lists open. Are you sure you want to quit without saving?','Quit VastTools','Yes','No','Yes');
      if strcmp(res,'No')
        return;
      end
    end;
  end;
    
  try
    %%%% CLEANUP
    % Disconnect if XTLibServer is connected
    if (vdata.state.isconnected==1)
      vdata.vast.disconnect();
    end;

    % Close simple navigator windows
    if (vdata.data.nrofsimplenavigators>0)
      for instance=1:1:vdata.data.nrofsimplenavigators
        if ishandle(vdata.data.sn(instance).fh)
          delete(vdata.data.sn(instance).fh);
        end
        vdata.data.sn(instance).open=0;
      end;
    end;
    
    % Close target list windows
    if (vdata.data.nroftargetlists>0)
      for instance=1:1:vdata.data.nroftargetlists
        if ishandle(vdata.data.tl(instance).fh)
          delete(vdata.data.tl(instance).fh);
        end
        vdata.data.tl(instance).open=0;
      end;
    end;
    
    % Close euclidian tool window if open
    if ishandle(vdata.etfh)
      delete(vdata.etfh);
    end;
    
    % Close move segments tool window if open
    if ishandle(vdata.msfh)
      delete(vdata.msfh);
    end;
    
    % Close main window
    if ishandle(vdata.fh)
      delete(vdata.fh);
    end
  catch err
    %If something went wrong, delete the current figure.
    delete(gcf);
  end;
  clear -global vdata;
  
  
function [] = callback_resize(varargin)
  global vdata;
  set(vdata.fh,'Units','pixels');
  pos = get(vdata.fh,'OuterPosition');
  hpos=pos(3)+(-1024+560);
  vpos=pos(4)-100;
  pos=get(vdata.fh,'Position');
  set(vdata.ui.cancelbutton,'position',[5 pos(4)-30 55 25]);
  set(vdata.ui.message,'position',[65 5 pos(3)-70 pos(4)-10]);


function [] = updategui()
  global vdata;
  if ((vdata.state.guiblocked)||(vdata.state.isconnected==0))
    set(vdata.ui.menu.exportobj,'Enable','off');
    set(vdata.ui.menu.exportparticles,'Enable','off');
    set(vdata.ui.menu.exportprojection,'Enable','off');
    set(vdata.ui.menu.exportbox,'Enable','off');
    set(vdata.ui.menu.exportscalebar,'Enable','off');
    set(vdata.ui.menu.measurevolumes,'Enable','off');
    set(vdata.ui.menu.euclidiantool,'Enable','off');
  else
    set(vdata.ui.menu.exportobj,'Enable','on');
    set(vdata.ui.menu.exportparticles,'Enable','on');
    set(vdata.ui.menu.exportprojection,'Enable','on');
    set(vdata.ui.menu.exportbox,'Enable','on');
    set(vdata.ui.menu.exportscalebar,'Enable','on');
    set(vdata.ui.menu.measurevolumes,'Enable','on');
    set(vdata.ui.menu.euclidiantool,'Enable','on');
  end;
  
function [] = blockgui()
  global vdata;
  vdata.state.guiblocked=1; 
  updategui();
  
function [] = releasegui()
  global vdata;
  vdata.state.guiblocked=0; 
  updategui();
  
function [] = setcanceledmsg()
  global vdata;
  set(vdata.ui.message,'String','Canceled.');
  set(vdata.ui.cancelbutton,'Enable','off');
  vdata.state.lastcancel=0;
  pause(0.1);
  

function [] = callback_done(varargin)
  global vdata;
  vdata.state.lastcancel=0;
  vdata.ui.temp.closefig=1;
  uiresume(gcbf);
  
  
function [] = callback_canceled(varargin)
  global vdata;
  vdata.state.lastcancel=1;
  vdata.ui.temp.closefig=1;
  uiresume(gcbf);


function [] = callback_connect(varargin)
  global vdata;
  
  if (vdata.state.isconnected==0)
    %Try to connect
    res=vdata.vast.connect(vdata.state.connect.ip,vdata.state.connect.port,1000);
    if (res==0)
      warndlg(['ERROR: Connecting to VAST at ' vdata.state.connect.ip ' port ' sprintf('%d',vdata.state.connect.port) ' failed. Please enable the Remote Control Server in VAST (in the main menu under "Window", "Remote Control API Server"; click "Enable") and make sure the IP and Port settings are correct!'],'Error connecting to VAST');
      return;
    end;
    vdata.state.isconnected=1;
    set(vdata.ui.menu.connectvast,'Label','Disconnect from VAST');
    set(vdata.ui.menu.connectmenu,'Label','Disconnect');
    set(vdata.ui.menu.exportobj,'Enable','on');
    set(vdata.ui.menu.exportparticles,'Enable','on');
%     set(vdata.ui.menu.exportprojection,'Enable','on');
%     set(vdata.ui.menu.measurevolumes,'Enable','on');
%     %set(vdata.ui.menu.measurelengths,'Enable','on');
%     set(vdata.ui.menu.euclidiantool,'Enable','on');
    updategui();
  else
    %Disconnect
    res=vdata.vast.disconnect();
    if (res==0)
      warndlg('ERROR: Disconnecting from VAST failed.','Error disconnecting from VAST');
      return;
    end
    vdata.state.isconnected=0;
    set(vdata.ui.menu.connectvast,'Label','Connect to VAST');
    set(vdata.ui.menu.connectmenu,'Label','Connect');
%     set(vdata.ui.menu.exportobj,'Enable','off');
%     set(vdata.ui.menu.exportprojection,'Enable','off');
%     set(vdata.ui.menu.measurevolumes,'Enable','off');
%     %set(vdata.ui.menu.measurelengths,'Enable','off');
%     set(vdata.ui.menu.euclidiantool,'Enable','off');
    updategui();
    
    if (isfield(vdata.data,'exportobj'))
      vdata.data=rmfield(vdata.data,'exportobj'); %Remove stored info about object exporting since it might be wrong when another data set is opened
    end;
    if (isfield(vdata.data,'exportbox'))
      vdata.data=rmfield(vdata.data,'exportbox'); %Remove stored info about object exporting since it might be wrong when another data set is opened
    end;
    if (isfield(vdata.data,'exportscalebar'))
      vdata.data=rmfield(vdata.data,'exportscalebar'); %Remove stored info about object exporting since it might be wrong when another data set is opened
    end;
    if (isfield(vdata.data,'exportproj'))
      vdata.data=rmfield(vdata.data,'exportproj'); %Remove stored info about object exporting since it might be wrong when another data set is opened
    end;
    if (isfield(vdata.data,'measurevol'))
      vdata.data=rmfield(vdata.data,'measurevol'); %Remove stored info about object exporting since it might be wrong when another data set is opened
    end;
  end;
  
  
function [] = callback_connectionoptions(varargin)
  global vdata;
  
  %blockgui();
  scrsz = get(0,'ScreenSize');
  figheight=160;
  f = figure('units','pixels','position',[50 scrsz(4)-100-figheight 360 figheight],'menubar','none','numbertitle','off','name','VastTools - Connection Options','resize','off');
  vpos=figheight-40;
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 160 15],'String','IP address of VAST computer:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos-20 300 15],'String','(use 127.0.0.1 if VAST runs on the same computer)','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e1 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[200 vpos 100 20],'String',vdata.state.connect.ip,'horizontalalignment','left');
  vpos=vpos-60;
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 160 15],'String','Port Address (default is 22081):','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e2 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[200 vpos 100 20],'String',sprintf('%d',vdata.state.connect.port),'horizontalalignment','left');
  vpos=vpos-30;
  
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[80 20 60 20], 'String','OK', 'CallBack',{@callback_done});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[220 20 60 20], 'String','Cancel', 'CallBack',{@callback_canceled});

  vdata.state.lastcancel=1;
  vdata.ui.temp.closefig=0;
  uiwait(f);
  
  if (vdata.state.lastcancel==0)
    vdata.state.connect.ip=get(e1,'String');
    vdata.state.connect.port = str2num(get(e2,'String'));
  end;
  
  if (vdata.ui.temp.closefig==1) %to distinguish close on button press and close on window x
    close(f);
  end;
  %releasegui();
  
  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 3D Surface OBJ Exporting Functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [] = callback_exportobj(varargin)
  global vdata;
  
  if (~checkconnection()) return; end;

  vinfo=vdata.vast.getinfo();
  
  if (min([vinfo.datasizex vinfo.datasizey vinfo.datasizez])==0)
    warndlg('ERROR: No volume open in VAST.','VastTools OBJ exporting');
    return;
  end;
  
% Not needed because export from image stacks is now also possible
%   nrofsegments=vdata.vast.getnumberofsegments();
%   if (nrofsegments==0)
%     warndlg('ERROR: No segmentation available in VAST.','VastTools OBJ exporting');
%     return;
%   end;
  
  blockgui();
  
  %Display parameter dialog
  if (~isfield(vdata.data,'region'))
    vdata.data.region.xmin=0;
    vdata.data.region.xmax=vinfo.datasizex-1;
    vdata.data.region.ymin=0;
    vdata.data.region.ymax=vinfo.datasizey-1;
    vdata.data.region.zmin=0; %first slice
    vdata.data.region.zmax=vinfo.datasizez-1; %last slice
  else
    if (vdata.data.region.xmin<0) vdata.data.region.xmin=0; end;
    if (vdata.data.region.xmax>(vinfo.datasizex-1)) vdata.data.region.xmax=vinfo.datasizex-1; end;
    if (vdata.data.region.ymin<0) vdata.data.region.ymin=0; end;
    if (vdata.data.region.ymax>(vinfo.datasizey-1)) vdata.data.region.ymax=vinfo.datasizey-1; end;
    if (vdata.data.region.zmin<0) vdata.data.region.zmin=0; end; %first slice
    if (vdata.data.region.zmax>(vinfo.datasizez-1)) vdata.data.region.zmax=vinfo.datasizez-1; end;
  end;
  if (~isfield(vdata.data,'exportobj'))
    vdata.data.exportobj.miplevel=0;
    vdata.data.exportobj.slicestep=1;     %4 means for example that every 4th slice exists (0, 4, 8, 12, ...)

    vdata.data.exportobj.blocksizex=1024; %Data block size for processing. For small data sets, make this a bit larger than the data (otherwise objects may be open)
    vdata.data.exportobj.blocksizey=1024;
    vdata.data.exportobj.blocksizez=64;
    vdata.data.exportobj.overlap=1;     %Leave this at 1
    vdata.data.exportobj.xscale=0.001;  %Use these to scale the exported models
    vdata.data.exportobj.yscale=0.001;
    vdata.data.exportobj.zscale=0.001;
    vdata.data.exportobj.xunit=vinfo.voxelsizex;%6*4;  %in nm
    vdata.data.exportobj.yunit=vinfo.voxelsizey; %6*4;  %in nm
    vdata.data.exportobj.zunit=vinfo.voxelsizez; %30; %in nm
    vdata.data.exportobj.outputoffsetx=0; %to translate the exported models in space
    vdata.data.exportobj.outputoffsety=0;
    vdata.data.exportobj.outputoffsetz=0;
    vdata.data.exportobj.invertz=1;

    vdata.data.exportobj.extractwhich=2;
    vdata.data.exportobj.objectcolors=1;
    vdata.data.exportobj.targetfileprefix='Segment_';
    vdata.data.exportobj.targetfolder=pwd;
    vdata.data.exportobj.includefoldernames=1;
    vdata.data.exportobj.closesurfaces=1;
    vdata.data.exportobj.skipmodelgeneration=0;
    vdata.data.exportobj.write3dsmaxloader=1;
    vdata.data.exportobj.savesurfacestats=0;
    vdata.data.exportobj.surfacestatsfile='surfacestats.txt';
  else
    if (vdata.data.exportobj.miplevel>(vinfo.nrofmiplevels-1)) vdata.data.exportobj.miplevel=vinfo.nrofmiplevels-1; end;
  end;
  
  scrsz = get(0,'ScreenSize');
  figheight=630;
  f = figure('units','pixels','position',[50 scrsz(4)-100-figheight 500 figheight],'menubar','none','numbertitle','off','name','VastTools - Export 3D Objects as OBJ Files','resize','off');

  vpos=figheight-40;
 
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 120 15], 'Tag','t1','String','Render at resolution:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  str=cell(vinfo.nrofmiplevels,1);
  vx=vinfo.voxelsizex;
  vy=vinfo.voxelsizey;
  vz=vinfo.voxelsizez;
  for i=1:1:vinfo.nrofmiplevels
    str{i}=sprintf('Mip %d - (%.2f nm, %.2f nm, %.2f nm) voxels',i-1,vx,vy,vz);
    vx=vx*2; vy=vy*2;
  end;
  pmh = uicontrol('Style','popupmenu','String',str,'Value',vdata.data.exportobj.miplevel+1,'Position',[170 vpos 310 20]);
  vpos=vpos-30;

  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 150 15],'String','Use every nth slice:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e1 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%d',vdata.data.exportobj.slicestep),'horizontalalignment','left');
  vpos=vpos-40;
  
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 120 15],'String','Render from area:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[340 vpos+10 140 20], 'String','Set to full', 'CallBack',{@callback_region_settofull,0});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[340 vpos-15 140 20], 'String','Set to selected bbox', 'CallBack',{@callback_region_settobbox,0});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[340 vpos-40 140 20], 'String','Set to current voxel', 'CallBack',{@callback_region_settocurrentvoxel,0});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[340 vpos-65 140 20], 'String','Extend to current voxel', 'CallBack',{@callback_region_extendtocurrentvoxel,0});
  
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[130 vpos 100 15],'String','X min:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_xmin = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%d', vdata.data.region.xmin),'horizontalalignment','left');
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[230 vpos 100 15],'String','X max:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_xmax = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[270 vpos 50 20],'String',sprintf('%d',vdata.data.region.xmax),'horizontalalignment','left');
  vpos=vpos-30;
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[130 vpos 100 15],'String','Y min:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_ymin = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%d',vdata.data.region.ymin),'horizontalalignment','left');
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[230 vpos 100 15],'String','Y max:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_ymax = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[270 vpos 50 20],'String',sprintf('%d',vdata.data.region.ymax),'horizontalalignment','left');
  vpos=vpos-30;
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[130 vpos 100 15],'String','Z min:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_zmin = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%d',vdata.data.region.zmin),'horizontalalignment','left');
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[230 vpos 100 15],'String','Z max:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_zmax = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[270 vpos 50 20],'String',sprintf('%d',vdata.data.region.zmax),'horizontalalignment','left');
  vpos=vpos-40;

  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 150 15],'String','Voxel size (full res)  X:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e8 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%f', vdata.data.exportobj.xunit),'horizontalalignment','left');
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[240 vpos 150 15],'String','Y:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e9 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[260 vpos 50 20],'String',sprintf('%f', vdata.data.exportobj.yunit),'horizontalalignment','left');
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[330 vpos 150 15],'String','Z:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e10 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[350 vpos 50 20],'String',sprintf('%f', vdata.data.exportobj.zunit),'horizontalalignment','left');
  vpos=vpos-20;
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[60 vpos 400 15], 'Tag','t1','String',sprintf('[VAST reports the voxel size to be: (%.2f nm, %.2f nm, %.2f nm)]',vinfo.voxelsizex,vinfo.voxelsizey,vinfo.voxelsizez),'backgroundcolor',get(f,'color'),'horizontalalignment','left');
  set(t,'tooltipstring','To change, enter the values in VAST under "Info / Volume properties" and save to your EM stack file.');
  vpos=vpos-30;
  
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 150 15],'String','Scale models by   X:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e11 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%f',vdata.data.exportobj.xscale),'horizontalalignment','left');
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[240 vpos 150 15],'String','Y:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e12 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[260 vpos 50 20],'String',sprintf('%f',vdata.data.exportobj.yscale),'horizontalalignment','left');
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[330 vpos 150 15],'String','Z:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e13 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[350 vpos 50 20],'String',sprintf('%f',vdata.data.exportobj.zscale),'horizontalalignment','left');
  vpos=vpos-30;
  
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 150 15],'String','Model output offset   X:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e14 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%f',vdata.data.exportobj.outputoffsetx),'horizontalalignment','left');
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[240 vpos 150 15],'String','Y:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e15 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[260 vpos 50 20],'String',sprintf('%f',vdata.data.exportobj.outputoffsety),'horizontalalignment','left');
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[330 vpos 150 15],'String','Z:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e16 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[350 vpos 50 20],'String',sprintf('%f',vdata.data.exportobj.outputoffsetz),'horizontalalignment','left');
  vpos=vpos-40;
  
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 150 15],'String','Processing block size   X:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e17 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%d',vdata.data.exportobj.blocksizex),'horizontalalignment','left');
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[240 vpos 150 15],'String','Y:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e18 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[260 vpos 50 20],'String',sprintf('%d',vdata.data.exportobj.blocksizey),'horizontalalignment','left');
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[330 vpos 150 15],'String','Z:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e19 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[350 vpos 50 20],'String',sprintf('%d',vdata.data.exportobj.blocksizez),'horizontalalignment','left');
  vpos=vpos-40;
  
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 100 15], 'Tag','t1','String','Export what:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  str=cell(8,1);
  str{1}='All segments individually, uncollapsed';
  str{2}='All segments, collapsed as in VAST';
  str{3}='Selected segment and children, uncollapsed';
  str{4}='Selected segment and children, collapsed as in VAST';
  str{5}='R, G, B isosurfaces from screenshots, at 50%';
  str{6}='Isosurfaces from screenshots, 16 brightness levels';
  str{7}='Isosurfaces from screenshots, 32 brightness levels';
  str{8}='Isosurfaces from screenshots, 64 brightness levels';
  pmh2 = uicontrol('Style','popupmenu','String',str,'Value',vdata.data.exportobj.extractwhich,'Position',[120 vpos 290 20]);
  vpos=vpos-30;
  
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 100 15],'String','File name prefix:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e20 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[120 vpos 290 20],'String',vdata.data.exportobj.targetfileprefix,'horizontalalignment','left');
  vpos=vpos-30;
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 100 15],'String','Object colors:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  str=cell(2,1);
  str{1}='Object colors from VAST';
  str{2}='Object volumes as JET colormap';
  pmh3 = uicontrol('Style','popupmenu','String',str,'Value',vdata.data.exportobj.objectcolors,'Position',[120 vpos 290 20]);
  vpos=vpos-30;
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 100 15],'String','Target folder:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e21 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[120 vpos 290 20],'String',vdata.data.exportobj.targetfolder,'horizontalalignment','left');
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[420 vpos 60 20], 'String','Browse...', 'CallBack',{@callback_exportobj_browse});
  vpos=vpos-30;
  
  c1 = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[30 vpos 250 15],'Value',vdata.data.exportobj.includefoldernames,'string','Include Vast folder names in file names','backgroundcolor',get(f,'color')); 
  c2 = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[300 vpos 200 15],'Value',vdata.data.exportobj.invertz,'string','Invert Z axis','backgroundcolor',get(f,'color')); 
  vpos=vpos-25;
  c3 = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[300 vpos 200 15],'Value',vdata.data.exportobj.closesurfaces,'string','Close surface sides','backgroundcolor',get(f,'color')); 
  c4 = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[30 vpos 250 15],'Value',vdata.data.exportobj.write3dsmaxloader,'string','Write 3dsMax bulk loader script to folder','backgroundcolor',get(f,'color')); 
  vpos=vpos-25;
  c5 = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[30 vpos 250 15],'Value',vdata.data.exportobj.skipmodelgeneration,'string','Skip model file generation','backgroundcolor',get(f,'color')); 
  vpos=vpos-30;
  
  c6 = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[30 vpos+3 250 15],'Value',vdata.data.exportobj.savesurfacestats,'string','Save surface statistics to file:','backgroundcolor',get(f,'color')); 
  e21 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[210 vpos 200 20],'String',vdata.data.exportobj.surfacestatsfile,'horizontalalignment','left');
  
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[150 20 60 20], 'String','OK', 'CallBack',{@callback_done});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[290 20 60 20], 'String','Cancel', 'CallBack',{@callback_canceled});

  vdata.state.lastcancel=1;
  vdata.ui.temp.closefig=0;
  uiwait(f);
  
  if (vdata.state.lastcancel==0)
    vdata.data.exportobj.miplevel=get(pmh,'value')-1;
    vdata.data.exportobj.slicestep = str2num(get(e1,'String'));
    vdata.data.region.xmin = str2num(get(vdata.temp.e_xmin,'String'));
    vdata.data.region.xmax = str2num(get(vdata.temp.e_xmax,'String'));
    vdata.data.region.ymin = str2num(get(vdata.temp.e_ymin,'String'));
    vdata.data.region.ymax = str2num(get(vdata.temp.e_ymax,'String'));
    vdata.data.region.zmin = str2num(get(vdata.temp.e_zmin,'String'));
    vdata.data.region.zmax = str2num(get(vdata.temp.e_zmax,'String'));
    
    vdata.data.exportobj.xunit = str2num(get(e8,'String'));
    vdata.data.exportobj.yunit = str2num(get(e9,'String'));
    vdata.data.exportobj.zunit = str2num(get(e10,'String'));
    vdata.data.exportobj.xscale = str2num(get(e11,'String'));
    vdata.data.exportobj.yscale = str2num(get(e12,'String'));
    vdata.data.exportobj.zscale = str2num(get(e13,'String'));
    vdata.data.exportobj.outputoffsetx = str2num(get(e14,'String'));
    vdata.data.exportobj.outputoffsety = str2num(get(e15,'String'));
    vdata.data.exportobj.outputoffsetz = str2num(get(e16,'String'));
    vdata.data.exportobj.blocksizex = str2num(get(e17,'String'));
    vdata.data.exportobj.blocksizey = str2num(get(e18,'String'));
    vdata.data.exportobj.blocksizez = str2num(get(e19,'String'));
    
    vdata.data.exportobj.extractwhich=get(pmh2,'value');
    vdata.data.exportobj.exportmodestring=get(pmh2,'string');
    vdata.data.exportobj.exportmodestring=vdata.data.exportobj.exportmodestring{vdata.data.exportobj.extractwhich};
    vdata.data.exportobj.objectcolors=get(pmh3,'value');
    vdata.data.exportobj.targetfileprefix=get(e20,'String');
    vdata.data.exportobj.targetfolder=get(vdata.temp.e21,'String');
    vdata.data.exportobj.includefoldernames = get(c1,'value');
    vdata.data.exportobj.invertz = get(c2,'value');
    vdata.data.exportobj.closesurfaces = get(c3,'value');
    vdata.data.exportobj.write3dsmaxloader = get(c4,'value');
    vdata.data.exportobj.skipmodelgeneration = get(c5,'value');
    
    vdata.data.exportobj.savesurfacestats = get(c6,'value');
    vdata.data.exportobj.surfacestatsfile = get(e21,'String');
  end;
  
  if (vdata.ui.temp.closefig==1) %to distinguish close on button press and close on window x
    close(f);
  end;

  if (vdata.state.lastcancel==0)
    
    if (vdata.data.exportobj.objectcolors==2)
      if (~isfield(vdata.data,'measurevol'))
        warndlg('ERROR: To use segment volume colors, please compute volumes first ("Measure / Measure Segment Volumes" in the main menu)!','Export 3D Surfaces as OBJ Files');
        releasegui();
        return;
      end;
      if (~isfield(vdata.data.measurevol,'lastvolume'))
        warndlg('ERROR: To use segment volume colors, please compute volumes first ("Measure / Measure Segment Volumes" in the main menu)!','Export 3D Surfaces as OBJ Files');
        releasegui();
        return;
      end;
    end;
    
    if ((vdata.data.exportobj.targetfolder(end)~='/')&&(vdata.data.exportobj.targetfolder(end)~='\'))
      vdata.data.exportobj.targetfolder=[vdata.data.exportobj.targetfolder '/'];
    end;
    
    if ((vdata.data.exportobj.xunit==0)||(vdata.data.exportobj.yunit==0)||(vdata.data.exportobj.zunit==0))
      res = questdlg(sprintf('Warning: The voxel size is set to (%f,%f,%f) which will result in collapsed models. Are you sure you want to continue?',vdata.data.exportobj.xunit,vdata.data.exportobj.yunit,vdata.data.exportobj.zunit),'Export 3D Surfaces as OBJ Files','Yes','No','Yes');
      if strcmp(res,'No')
        releasegui();
        return; 
      end
    end;
    
    extractsurfaces();
  end;  
  releasegui();  
  
  
function [] = callback_region_settofull(varargin)
  global vdata;
  vinfo=vdata.vast.getinfo();
  vdata.data.region.xmin=0;
  vdata.data.region.xmax=vinfo.datasizex-1;
  vdata.data.region.ymin=0;
  vdata.data.region.ymax=vinfo.datasizey-1;
  vdata.data.region.zmin=0; %first slice
  vdata.data.region.zmax=vinfo.datasizez-1; %last slice
  set(vdata.temp.e_xmin,'String',sprintf('%d', vdata.data.region.xmin));
  set(vdata.temp.e_xmax,'String',sprintf('%d', vdata.data.region.xmax));
  set(vdata.temp.e_ymin,'String',sprintf('%d', vdata.data.region.ymin));
  set(vdata.temp.e_ymax,'String',sprintf('%d', vdata.data.region.ymax));
  set(vdata.temp.e_zmin,'String',sprintf('%d', vdata.data.region.zmin));
  set(vdata.temp.e_zmax,'String',sprintf('%d', vdata.data.region.zmax));
  if (varargin{3}==1) callback_update_targetimagesize(); end;
  
  
function [] = callback_region_settobbox(varargin)
  global vdata;
  [data,res] = vdata.vast.getallsegmentdatamatrix();
  selected=find(bitand(data(:,2),65536)>0);
  if (min(size(selected))==0)
    selected=data(:,1);
  else
    selected=[selected getchildtreeids(data,selected)];
  end;
  bbx=data(selected,19:24);
  bbx(bbx(:,3)==-1,:)=[]; %remove -1s
  minxyz=min(bbx(:,1:3),[],1);
  maxxyz=max(bbx(:,4:6),[],1);
  if (min(size(bbx))==0)
    warndlg('ERROR - Cannot set area, bounding box undefined.','VastTools - Bounding Box');
    return;
  end;
  vdata.data.region.xmin=minxyz(1);
  vdata.data.region.xmax=maxxyz(1);
  vdata.data.region.ymin=minxyz(2);
  vdata.data.region.ymax=maxxyz(2);
  vdata.data.region.zmin=minxyz(3); %first slice
  vdata.data.region.zmax=maxxyz(3); %last slice
  set(vdata.temp.e_xmin,'String',sprintf('%d', vdata.data.region.xmin));
  set(vdata.temp.e_xmax,'String',sprintf('%d', vdata.data.region.xmax));
  set(vdata.temp.e_ymin,'String',sprintf('%d', vdata.data.region.ymin));
  set(vdata.temp.e_ymax,'String',sprintf('%d', vdata.data.region.ymax));
  set(vdata.temp.e_zmin,'String',sprintf('%d', vdata.data.region.zmin));
  set(vdata.temp.e_zmax,'String',sprintf('%d', vdata.data.region.zmax));
  if (varargin{3}==1) callback_update_targetimagesize(); end;
  warndlg('Area set to combined bounding box of selected segment and its children. - CAUTION: Bounding boxes may be not always correct. Please make sure you cover the intended region.','Using Bounding Boxes in VastTools');
  
  
function [] = callback_region_settocurrentvoxel(varargin)
  global vdata;
  vinfo=vdata.vast.getinfo();
  vdata.data.region.xmin=vinfo.currentviewx;
  vdata.data.region.xmax=vinfo.currentviewx;
  vdata.data.region.ymin=vinfo.currentviewy;
  vdata.data.region.ymax=vinfo.currentviewy;
  vdata.data.region.zmin=vinfo.currentviewz; %first slice
  vdata.data.region.zmax=vinfo.currentviewz; %last slice
  set(vdata.temp.e_xmin,'String',sprintf('%d', vdata.data.region.xmin));
  set(vdata.temp.e_xmax,'String',sprintf('%d', vdata.data.region.xmax));
  set(vdata.temp.e_ymin,'String',sprintf('%d', vdata.data.region.ymin));
  set(vdata.temp.e_ymax,'String',sprintf('%d', vdata.data.region.ymax));
  set(vdata.temp.e_zmin,'String',sprintf('%d', vdata.data.region.zmin));
  set(vdata.temp.e_zmax,'String',sprintf('%d', vdata.data.region.zmax));
  if (varargin{3}==1) callback_update_targetimagesize(); end;
  
  
function [] = callback_region_extendtocurrentvoxel(varargin)
  global vdata;
  vinfo=vdata.vast.getinfo();
  vdata.data.region.xmin=min([vdata.data.region.xmin vinfo.currentviewx]);
  vdata.data.region.xmax=max([vdata.data.region.xmax vinfo.currentviewx]);
  vdata.data.region.ymin=min([vdata.data.region.ymin vinfo.currentviewy]);
  vdata.data.region.ymax=max([vdata.data.region.ymax vinfo.currentviewy]);
  vdata.data.region.zmin=min([vdata.data.region.zmin vinfo.currentviewz]);
  vdata.data.region.zmax=max([vdata.data.region.zmax vinfo.currentviewz]);
  set(vdata.temp.e_xmin,'String',sprintf('%d', vdata.data.region.xmin));
  set(vdata.temp.e_xmax,'String',sprintf('%d', vdata.data.region.xmax));
  set(vdata.temp.e_ymin,'String',sprintf('%d', vdata.data.region.ymin));
  set(vdata.temp.e_ymax,'String',sprintf('%d', vdata.data.region.ymax));
  set(vdata.temp.e_zmin,'String',sprintf('%d', vdata.data.region.zmin));
  set(vdata.temp.e_zmax,'String',sprintf('%d', vdata.data.region.zmax));
  if (varargin{3}==1) callback_update_targetimagesize(); end;

  
function [] = callback_exportobj_browse(varargin)
  global vdata;
  foldername = uigetdir(vdata.data.exportobj.targetfolder,'VastTools - Select target folder for OBJ files:');
  if (foldername~=0)
    set(vdata.temp.e21,'String',foldername);
    vdata.data.exportobj.targetfolder=foldername;
  end;
  
  
function [] = extractsurfaces()
  global vdata;
  
  if (~checkconnection()) return; end;
  
  set(vdata.ui.cancelbutton,'Enable','on');
  set(vdata.ui.message,'String',{'Exporting Surfaces ...','Loading Metadata ...'});
  pause(0.1);
  
  param=vdata.data.exportobj;
  rparam=vdata.data.region;
  extractseg=1;
  if ((param.extractwhich==5)||(param.extractwhich==6)||(param.extractwhich==7)||(param.extractwhich==8)) extractseg=0; end;
    
  if (extractseg)
    [data,res] = vdata.vast.getallsegmentdatamatrix();
    [name,res] = vdata.vast.getallsegmentnames();
    seglayername=getselectedseglayername();
    name(1)=[]; %remove 'Background'
    maxobjectnumber=max(data(:,1));
  else
    switch param.extractwhich
      case 5 %RGB 50%
        name={'Red Layer', 'Green Layer', 'Blue Layer'};
      case 6 %16 levels
        param.lev=8:16:256;
        for i=1:length(param.lev)
          name{i}=sprintf('B%03d',param.lev(i));
        end;
      case 7 %32 levels
        param.lev=4:8:256;
        for i=1:length(param.lev)
          name{i}=sprintf('B%03d',param.lev(i));
        end;
      case 8 %64 levels
        param.lev=2:4:256;
        for i=1:length(param.lev)
          name{i}=sprintf('B%03d',param.lev(i));
        end;
    end;
  end;
  
  xmin=bitshift(rparam.xmin,-param.miplevel);
  xmax=bitshift(rparam.xmax,-param.miplevel)-1;
  ymin=bitshift(rparam.ymin,-param.miplevel);
  ymax=bitshift(rparam.ymax,-param.miplevel)-1;
  zmin=rparam.zmin;
  zmax=rparam.zmax;
  
  mipfact=bitshift(1,param.miplevel);
  
  if (((xmin==xmax)||(ymin==ymax)||(zmin==zmax))&&(param.closesurfaces==0))
    warndlg('ERROR: The Matlab surface script needs a volume which is at least two pixels wide in each direction to work. Please adjust "Render from area" values, or enable "Close surface sides".','VastTools OBJ Exporting');
    set(vdata.ui.message,'String','Canceled.');
    set(vdata.ui.cancelbutton,'Enable','off');
    vdata.state.lastcancel=0;
    return;
  end;
  
  if (extractseg)
    % Compute full name (including folder names) from name and hierarchy
    if (param.includefoldernames==1)
      fullname=name;
      for i=1:1:size(data,1)
        j=i;
        while data(j,14)~=0 %Check if parent is not 0
          j=data(j,14);
          fullname{i}=[name{j} '.' fullname{i}];
        end;
      end;
      name=fullname;
    end;
  
    % Compute list of objects to export
    switch param.extractwhich
      case 1  %All segments individually, uncollapsed
        objects=uint32([data(:,1) data(:,2)]);
        vdata.vast.setsegtranslation([],[]);
        
      case 2  %All segments, collapsed as in Vast
        %4: Collapse segments as in the view during segment text file exporting
        objects=unique(data(:,18));
        objects=uint32([objects data(objects,2)]);
        vdata.vast.setsegtranslation(data(:,1),data(:,18));
        
      case 3  %Selected segment and children, uncollapsed
        selected=find(bitand(data(:,2),65536)>0);
        if (min(size(selected))==0)
          objects=uint32([data(:,1) data(:,2)]);
        else
          selected=[selected getchildtreeids(data,selected)];
          objects=uint32([selected' data(selected,2)]);
        end;
        vdata.vast.setsegtranslation(data(selected,1),data(selected,1));
        
      case 4  %Selected segment and children, collapsed as in Vast
        selected=find(bitand(data(:,2),65536)>0);
        if (min(size(selected))==0)
          %None selected: choose all, collapsed
          selected=data(:,1);
          objects=unique(data(:,18));
        else
          selected=[selected getchildtreeids(data,selected)];
          objects=unique(data(selected,18));
        end;
        
        objects=uint32([objects data(objects,2)]);
        vdata.vast.setsegtranslation(data(selected,1),data(selected,18));
    end;
  end;
  
  
  % Compute number of blocks in volume
  nrxtiles=0; tilex1=xmin;
  while (tilex1<=xmax)
    tilex1=tilex1+param.blocksizex-param.overlap;
    nrxtiles=nrxtiles+1;
  end;
  nrytiles=0; tiley1=ymin;
  while (tiley1<=ymax)
    tiley1=tiley1+param.blocksizey-param.overlap;
    nrytiles=nrytiles+1;
  end;
  nrztiles=0; tilez1=zmin;
  if (vdata.data.exportobj.slicestep==1)
    slicenumbers=zmin:zmax;
    while (tilez1<=zmax)
      tilez1=tilez1+param.blocksizez-param.overlap;
      nrztiles=nrztiles+1;
    end;
  else
    slicenumbers=zmin:vdata.data.exportobj.slicestep:zmax;
    nrztiles=ceil(size(slicenumbers,2)/(param.blocksizez-param.overlap));
    j=1;
    for p=1:param.blocksizez-param.overlap:size(slicenumbers,2)
      pe=min([p+param.blocksizez-1 size(slicenumbers,2)]);
      blockslicenumbers{j}=slicenumbers(p:pe);
      j=j+1;
    end;
  end;
  param.nrxtiles=nrxtiles; param.nrytiles=nrytiles; param.nrztiles=nrztiles;
  
  if (extractseg)  
    %Go through all blocks and extract surfaces
    param.farray=cell(maxobjectnumber,param.nrxtiles,param.nrytiles,param.nrztiles);
    param.varray=cell(maxobjectnumber,param.nrxtiles,param.nrytiles,param.nrztiles);
    param.objects=objects;
    param.objectvolume=zeros(size(objects,1),1);
  else
    param.farray=cell(3,param.nrxtiles,param.nrytiles,param.nrztiles);
    param.varray=cell(3,param.nrxtiles,param.nrytiles,param.nrztiles);
    param.objects=[(1:length(name))' zeros(length(name),1)];
    param.objectvolume=zeros(length(name),1);
  end;

  tilez1=zmin; tz=1;
  while ((tz<=nrztiles)&&(vdata.state.lastcancel==0))
    tilez2=tilez1+param.blocksizez-1;
    if (tilez2>zmax) tilez2=zmax; end;
    tilezs=tilez2-tilez1+1;
    tiley1=ymin; ty=1;
    while ((ty<=nrytiles)&&(vdata.state.lastcancel==0))
      tiley2=tiley1+param.blocksizey-1;
      if (tiley2>ymax) tiley2=ymax; end;
      tileys=tiley2-tiley1+1;
      tilex1=xmin; tx=1;
      while ((tx<=nrxtiles)&&(vdata.state.lastcancel==0))
        tilex2=tilex1+param.blocksizex-1;
        if (tilex2>xmax) tilex2=xmax; end;
        tilexs=tilex2-tilex1+1;
        
        if (extractseg)
          message={'Exporting Surfaces ...',sprintf('Loading Segmentation Cube (%d,%d,%d) of (%d,%d,%d)...',tx,ty,tz,nrxtiles,nrytiles,nrztiles)};
          set(vdata.ui.message,'String',message);
          pause(0.01);
          %Read this cube
          if (vdata.data.exportobj.slicestep==1)
            [segimage,values,numbers,bboxes,res] = vdata.vast.getsegimageRLEdecodedbboxes(param.miplevel,tilex1,tilex2,tiley1,tiley2,tilez1,tilez2,0);
          else
            bs=blockslicenumbers{tz};
            segimage=uint16(zeros(tilex2-tilex1+1,tiley2-tiley1+1,size(bs,2)));
            numarr=int32(zeros(maxobjectnumber,1));
            bboxarr=zeros(maxobjectnumber,6)-1;
            firstblockslice=bs(1);
            for i=1:1:size(bs,2)
              [ssegimage,svalues,snumbers,sbboxes,res] = vdata.vast.getsegimageRLEdecodedbboxes(param.miplevel,tilex1,tilex2,tiley1,tiley2,bs(i),bs(i),0);
              segimage(:,:,i)=ssegimage;
              snumbers(svalues==0)=[];
              sbboxes(svalues==0,:)=[];
              sbboxes(:,[3 6])=sbboxes(:,[3 6])+i-1;
              svalues(svalues==0)=[];
              if (min(size(svalues))>0)
                numarr(svalues)=numarr(svalues)+snumbers;
                bboxarr(svalues,:)=vdata.vast.expandboundingboxes(bboxarr(svalues,:),sbboxes);
              end;
            end;
            values=find(numarr>0);
            numbers=numarr(values);
            bboxes=bboxarr(values,:);
          end;
        else
          message={'Exporting Surfaces ...',sprintf('Loading Screenshot Cube (%d,%d,%d) of (%d,%d,%d)...',tx,ty,tz,nrxtiles,nrytiles,nrztiles)};
          set(vdata.ui.message,'String',message);
          pause(0.01);
          %Read this cube
          if (vdata.data.exportobj.slicestep==1)
            %[segimage,values,numbers,bboxes,res] = vdata.vast.getsegimageRLEdecodedbboxes(param.miplevel,tilex1,tilex2,tiley1,tiley2,tilez1,tilez2,0);
            [scsimage,res] = vdata.vast.getscreenshotimage(param.miplevel,tilex1,tilex2,tiley1,tiley2,tilez1,tilez2,1);
          else
            bs=blockslicenumbers{tz};
            %segimage=uint16(zeros(tilex2-tilex1+1,tiley2-tiley1+1,size(bs,2)));
            scsimage=uint8(zeros(tilex2-tilex1+1,tiley2-tiley1+1,size(bs,2),3));
            %numarr=int32(zeros(maxobjectnumber,1));
            %bboxarr=zeros(maxobjectnumber,6)-1;
            firstblockslice=bs(1);
            for i=1:1:size(bs,2)
              %[ssegimage,svalues,snumbers,sbboxes,res] = vdata.vast.getsegimageRLEdecodedbboxes(param.miplevel,tilex1,tilex2,tiley1,tiley2,bs(i),bs(i),0);
              [scsslice,res] = vdata.vast.getscreenshotimage(param.miplevel,tilex1,tilex2,tiley1,tiley2,bs(i),bs(i),1);
              scsimage(:,:,i,:)=scsslice;
              %snumbers(svalues==0)=[];
              %sbboxes(svalues==0,:)=[];
              %sbboxes(:,[3 6])=sbboxes(:,[3 6])+i-1;
              %svalues(svalues==0)=[];
              %if (min(size(svalues))>0)
              %  numarr(svalues)=numarr(svalues)+snumbers;
              %  bboxarr(svalues,:)=vdata.vast.expandboundingboxes(bboxarr(svalues,:),sbboxes);
              %end;
            end;
            %values=find(numarr>0);
            %numbers=numarr(values);
            %bboxes=bboxarr(values,:);
          end;
        end;
        
        if (extractseg)
          message={'Exporting Surfaces ...',sprintf('Processing Segmentation Cube (%d,%d,%d) of (%d,%d,%d)...',tx,ty,tz,nrxtiles,nrytiles,nrztiles)};
          set(vdata.ui.message,'String',message);
          pause(0.01);
          
          numbers(values==0)=[];
          bboxes(values==0,:)=[];
          values(values==0)=[];
          
          if (min(size(values))>0)
            % VAST now translates the voxel data before transmission because Matlab is too slow.
            
            %Close surfaces
            xvofs=0; yvofs=0; zvofs=0; ttxs=tilexs; ttys=tileys; ttzs=tilezs;
            if (vdata.data.exportobj.closesurfaces==1)
              if (tx==1)
                segimage=cat(1,zeros(1,size(segimage,2),size(segimage,3)),segimage);
                bboxes(:,1)=bboxes(:,1)+1;
                bboxes(:,4)=bboxes(:,4)+1;
                xvofs=-1;
                ttxs=ttxs+1;
              end;
              if (ty==1)
                segimage=cat(2,zeros(size(segimage,1),1,size(segimage,3)),segimage);
                bboxes(:,2)=bboxes(:,2)+1;
                bboxes(:,5)=bboxes(:,5)+1;
                yvofs=-1;
                ttys=ttys+1;
              end;
              if (tz==1)
                segimage=cat(3,zeros(size(segimage,1),size(segimage,2),1),segimage);
                bboxes(:,3)=bboxes(:,3)+1;
                bboxes(:,6)=bboxes(:,6)+1;
                zvofs=-1;
                ttzs=ttzs+1;
              end;
              if (tx==nrxtiles)
                segimage=cat(1,segimage,zeros(1,size(segimage,2),size(segimage,3)));
                ttxs=ttxs+1;
              end;
              if (ty==nrytiles)
                segimage=cat(2,segimage,zeros(size(segimage,1),1,size(segimage,3)));
                ttys=ttys+1;
              end;
              if (tz==nrztiles)
                segimage=cat(3,segimage,zeros(size(segimage,1),size(segimage,2),1));
                ttzs=ttzs+1;
              end;
            end;
            
            %Extract all segments
            segnr=1;
            while ((segnr<=size(values,1))&&(vdata.state.lastcancel==0))
              seg=values(segnr);
              
              if (mod(segnr,10)==1)
                set(vdata.ui.message,'String',[message sprintf('Objects %d-%d of %d ...',segnr,min([segnr+9 size(values,1)]),size(values,1))]);
                pause(0.01);
              end;
              
              bbx=bboxes(segnr,:);
              bbx=bbx+[-1 -1 -1 1 1 1];
              if (bbx(1)<1) bbx(1)=1; end;
              if (bbx(2)<1) bbx(2)=1; end;
              if (bbx(3)<1) bbx(3)=1; end;
              if (bbx(4)>ttxs) bbx(4)=ttxs; end;
              if (bbx(5)>ttys) bbx(5)=ttys; end;
              if (bbx(6)>ttzs) bbx(6)=ttzs; end;
              
              %Adjust extracted subvolumes to be at least 2 pixels in each direction
              if (bbx(1)==bbx(4))
                if (bbx(1)>1)
                  bbx(1)=bbx(1)-1;
                else
                  bbx(4)=bbx(4)+1;
                end;
              end;
              if (bbx(2)==bbx(5))
                if (bbx(2)>1)
                  bbx(2)=bbx(2)-1;
                else
                  bbx(5)=bbx(5)+1;
                end;
              end;
              if (bbx(3)==bbx(6))
                if (bbx(3)>1)
                  bbx(3)=bbx(3)-1;
                else
                  bbx(6)=bbx(6)+1;
                end;
              end;
              
              subseg=segimage(bbx(1):bbx(4),bbx(2):bbx(5),bbx(3):bbx(6)); %(ymin:ymax,xmin:xmax,zmin:zmax);
              subseg=double(subseg==seg);
              
              [f,v]=isosurface(subseg,0.5);
              if (size(v,1)>0)
                %adjust coordinates for bbox and when we added empty slices at beginning
                v(:,1)=v(:,1)+bbx(2)-1+yvofs;
                v(:,2)=v(:,2)+bbx(1)-1+xvofs;
                v(:,3)=v(:,3)+bbx(3)-1+zvofs;
                
                v(:,1)=v(:,1)+tiley1-1;
                v(:,2)=v(:,2)+tilex1-1;
                if (vdata.data.exportobj.slicestep==1)
                  v(:,3)=v(:,3)+tilez1-1;
                else
                  v(:,3)=((v(:,3)-0.5)*vdata.data.exportobj.slicestep)+0.5+firstblockslice-1;
                end;
                v(:,1)=v(:,1)*param.yscale*param.yunit*mipfact;
                v(:,2)=v(:,2)*param.xscale*param.xunit*mipfact;
                v(:,3)=v(:,3)*param.zscale*param.zunit;
              end;
              param.farray{seg,tx,ty,tz}=f;
              param.varray{seg,tx,ty,tz}=v;
              
              segnr=segnr+1;
            end;
          end;
        else
          message={'Exporting Surfaces ...',sprintf('Processing Screenshot Cube (%d,%d,%d) of (%d,%d,%d)...',tx,ty,tz,nrxtiles,nrytiles,nrztiles)};
          set(vdata.ui.message,'String',message);
          pause(0.01);
          
          rcube=permute(squeeze(scsimage(:,:,:,1)),[2 1 3]);
          gcube=permute(squeeze(scsimage(:,:,:,2)),[2 1 3]);
          bcube=permute(squeeze(scsimage(:,:,:,3)),[2 1 3]);
          
          %Close surfaces
          xvofs=0; yvofs=0; zvofs=0; ttxs=tilexs; ttys=tileys; ttzs=tilezs;
          if (vdata.data.exportobj.closesurfaces==1)
            if (tx==1)
              %segimage=cat(1,zeros(1,size(segimage,2),size(segimage,3)),segimage);
              rcube=cat(1,zeros(1,size(rcube,2),size(rcube,3)),rcube);
              gcube=cat(1,zeros(1,size(gcube,2),size(gcube,3)),gcube);
              bcube=cat(1,zeros(1,size(bcube,2),size(bcube,3)),bcube);
              xvofs=-1;
              ttxs=ttxs+1;
            end;
            if (ty==1)
              %segimage=cat(2,zeros(size(segimage,1),1,size(segimage,3)),segimage);
              rcube=cat(2,zeros(size(rcube,1),1,size(rcube,3)),rcube);
              gcube=cat(2,zeros(size(gcube,1),1,size(gcube,3)),gcube);
              bcube=cat(2,zeros(size(bcube,1),1,size(bcube,3)),bcube);
              yvofs=-1;
              ttys=ttys+1;
            end;
            if (tz==1)
              %segimage=cat(3,zeros(size(segimage,1),size(segimage,2),1),segimage);
              rcube=cat(3,zeros(size(rcube,1),size(rcube,2),1),rcube);
              gcube=cat(3,zeros(size(gcube,1),size(gcube,2),1),gcube);
              bcube=cat(3,zeros(size(bcube,1),size(bcube,2),1),bcube);
              zvofs=-1;
              ttzs=ttzs+1;
            end;
            if (tx==nrxtiles)
              %segimage=cat(1,segimage,zeros(1,size(segimage,2),size(segimage,3)));
              rcube=cat(1,rcube,zeros(1,size(rcube,2),size(rcube,3)));
              gcube=cat(1,gcube,zeros(1,size(gcube,2),size(gcube,3)));
              bcube=cat(1,bcube,zeros(1,size(bcube,2),size(bcube,3)));
              ttxs=ttxs+1;
            end;
            if (ty==nrytiles)
              %segimage=cat(2,segimage,zeros(size(segimage,1),1,size(segimage,3)));
              rcube=cat(2,rcube,zeros(size(rcube,1),1,size(rcube,3)));
              gcube=cat(2,gcube,zeros(size(gcube,1),1,size(gcube,3)));
              bcube=cat(2,bcube,zeros(size(bcube,1),1,size(bcube,3)));
              ttys=ttys+1;
            end;
            if (tz==nrztiles)
              %segimage=cat(3,segimage,zeros(size(segimage,1),size(segimage,2),1));
              rcube=cat(3,rcube,zeros(size(rcube,1),size(rcube,2),1));
              gcube=cat(3,gcube,zeros(size(gcube,1),size(gcube,2),1));
              bcube=cat(3,bcube,zeros(size(bcube,1),size(bcube,2),1));
              ttzs=ttzs+1;
            end;
          end;
          
          %Extract isosurfaces
          if ((param.extractwhich==6)||(param.extractwhich==7)||(param.extractwhich==8))
            cube=uint8((int32(rcube)+int32(gcube)+int32(bcube))/3);
          end;
          obj=1;
          while ((obj<=size(param.objects,1))&&(vdata.state.lastcancel==0))
          %for obj=1:size(param.objects,1)
            if (param.extractwhich==5)
              switch obj
                case 1
                  subseg=double(rcube>128);
                case 2
                  subseg=double(gcube>128);
                case 3
                  subseg=double(bcube>128);
              end;
            end;
            if ((param.extractwhich==6)||(param.extractwhich==7)||(param.extractwhich==8))
              subseg=double(cube>param.lev(obj));
            end;
            [f,v]=isosurface(subseg,0.5);
            if (size(v,1)>0)
              %adjust coordinates for bbox and when we added empty slices at beginning
              v(:,1)=v(:,1)+yvofs;
              v(:,2)=v(:,2)+xvofs;
              v(:,3)=v(:,3)+zvofs;
              
              v(:,1)=v(:,1)+tiley1-1;
              v(:,2)=v(:,2)+tilex1-1;
              if (vdata.data.exportobj.slicestep==1)
                v(:,3)=v(:,3)+tilez1-1;
              else
                v(:,3)=((v(:,3)-0.5)*vdata.data.exportobj.slicestep)+0.5+firstblockslice-1;
              end;
              v(:,1)=v(:,1)*param.yscale*param.yunit*mipfact;
              v(:,2)=v(:,2)*param.xscale*param.xunit*mipfact;
              v(:,3)=v(:,3)*param.zscale*param.zunit;
            end;
            param.farray{obj,tx,ty,tz}=f;
            param.varray{obj,tx,ty,tz}=v;
            obj=obj+1;
          end;
        end;
        
        tilex1=tilex1+param.blocksizex-param.overlap;
        tx=tx+1;
      end;
      tiley1=tiley1+param.blocksizey-param.overlap;
      ty=ty+1;
    end;
    tilez1=tilez1+param.blocksizez-param.overlap;
    tz=tz+1;
  end;
  
  if (extractseg)
    vdata.vast.setsegtranslation([],[]);
  end;
  
  if (vdata.state.lastcancel==0)
    message={'Exporting Surfaces ...', 'Merging meshes...'};
    set(vdata.ui.message,'String',message);
    pause(0.01);
    
    if (extractseg)
      param.objectsurfacearea=zeros(size(objects,1),1);
      switch vdata.data.exportobj.objectcolors
        case 1  %actual object colors
          colors=zeros(size(param.objects,1),3);
          for segnr=1:1:size(param.objects,1)
            seg=param.objects(segnr,1);
            %Get color from where the color is currently inherited from
            inheritseg=data(seg,18);
            colors(seg,:)=data(inheritseg, 3:5);
          end;
        case 2  %colors from volume
          j=jet(256);
          vols=1+255*vdata.data.measurevol.lastvolume/max(vdata.data.measurevol.lastvolume);
          cols=j(round(vols),:);
          objs=vdata.data.measurevol.lastobjects(:,1);
          colors=zeros(size(param.objects,1),3); %vcols=zeros(nro,3);
          colors(objs,:)=cols*255;
      end;
    else
      if (param.extractwhich==5)
        colors=zeros(size(param.objects,1),3);
        colors(1,1)=255;
        colors(2,2)=255;
        colors(3,3)=255;
      end;
      if ((param.extractwhich==6)||(param.extractwhich==7)||(param.extractwhich==8))
        colors=[param.lev' param.lev' param.lev'];
      end;
    end;


    %Write 3dsmax bulk loader script
    if (vdata.data.exportobj.write3dsmaxloader==1)
      save3dsmaxloader([param.targetfolder 'loadallobj_here.ms']);
    end;
    
    %Merge full objects from components
    segnr=1;
    while ((segnr<=size(param.objects,1))&&(vdata.state.lastcancel==0))
      seg=param.objects(segnr,1);
      set(vdata.ui.message,'String',{'Exporting Surfaces ...', ['Merging parts of ' name{seg} '...']});
      pause(0.01);
      
      cofp=[];
      covp=[];
      vofs=0;

%       for z=1:1:param.nrztiles
%         for y=1:1:param.nrytiles
%           for x=1:1:param.nrxtiles
      z=1;
      while ((z<=param.nrztiles)&&(vdata.state.lastcancel==0))
        y=1;
        while ((y<=param.nrytiles)&&(vdata.state.lastcancel==0))
          x=1;
          while ((x<=param.nrxtiles)&&(vdata.state.lastcancel==0))
            if (x==1)
              f=param.farray{seg,x,y,z};
              v=param.varray{seg,x,y,z};
            else
              %disp(sprintf('Merging object %d, cube (%d,%d,%d)...',seg,x,y,z));
              [f,v]=mergemeshes(f,v,param.farray{seg,x,y,z},param.varray{seg,x,y,z});
            end;
            x=x+1;
          end;
          if (y==1)
            fc=f;
            vc=v;
          else
            %disp(sprintf('Merging object %d, row (%d,%d)...',seg,y,z));
            [fc,vc]=mergemeshes(fc,vc,f,v);
          end;
          y=y+1;
        end;
        if (z==1)
          fp=fc;
          vp=vc;
        else
          %disp(sprintf('Merging object %d, plane %d...',seg,z));
          [fp,vp]=mergemeshes(fp,vp,fc,vc);
          
          %Take out non-overlapping part of matrices to speed up computation
          if ((size(vp,1)>1)&&(size(fp,1)>1))
            vcut=find(vp(:,3)==max(vp(:,3)),1,'first')-1;
            fcutind=find(fp>vcut,1,'first');
            [fcut,j]=ind2sub(size(fp),fcutind); fcut=fcut-1;
          
            covp=[covp; vp(1:vcut,:)]; vp=vp(vcut+1:end,:);
            ovofs=vofs;
            vofs=vofs+vcut;
            cofp=[cofp; fp(1:fcut,:)+ovofs]; fp=fp(fcut+1:end,:)-vcut;
          end;
        end;
        z=z+1;
      end;
      
      vp=[covp; vp];
      fp=[cofp; fp+vofs];

      %invert Z axis if requested
      if (vdata.data.exportobj.invertz==1)
        if (size(vp,1)>0)
          vp(:,3)=-vp(:,3);
        end;
      end;
      
      %add offset if requested
      if (param.outputoffsetx~=0)
        vp(:,1)=vp(:,1)+param.outputoffsetx;
      end;
      if (param.outputoffsety~=0)
        vp(:,2)=vp(:,2)+param.outputoffsety;
      end;
      if (param.outputoffsetz~=0)
        vp(:,3)=vp(:,3)+param.outputoffsetz;
      end;
      
      if (extractseg)
        on=name{find(data(:,1)==seg)};
      else
        on=name{seg};
      end;
      on(on==' ')='_';
      on(on=='?')='_';
      on(on=='*')='_';
      on(on=='\')='_';
      on(on=='/')='_';
      on(on=='|')='_';
      on(on==':')='_';
      on(on=='"')='_';
      on(on=='<')='_';
      on(on=='>')='_';
      filename=[param.targetfolder param.targetfileprefix sprintf('_%04d_%s.obj',seg,on)];

      if ((vdata.data.exportobj.skipmodelgeneration==0)&&(max(size(vp))>0))
        objectname=[param.targetfileprefix sprintf('_%04d_%s',seg,name{seg})];
        mtlfilename=[param.targetfileprefix sprintf('_%04d_%s.mtl',seg,on)];
        mtlfilenamewithpath=[filename(1:end-3) 'mtl'];
        materialname=[param.targetfileprefix sprintf('_%04d_material',seg)];

        set(vdata.ui.message,'String',{'Exporting Surfaces ...', ['Saving ' filename ' as Wavefront OBJ.....']});
        pause(0.01);

        if (vdata.data.exportobj.invertz==1)
          vertface2obj_mtllink(vp,fp,filename,objectname,mtlfilename,materialname);
        else
          vertface2obj_mtllink_invnormal(vp,fp,filename,objectname,mtlfilename,materialname);
        end;

        savematerialfile(mtlfilenamewithpath,materialname,colors(seg,:)/255,1.0);
      end;
      
      param.vparray{seg}=vp;
      param.fparray{seg}=fp;
      
      %%%%%% Compute surface size
      if (vdata.data.exportobj.savesurfacestats==1)
        set(vdata.ui.message,'String',{'Exporting Surfaces ...', ['Evaluating surface area of ' name{seg} ' ...']});
        pause(0.01);
        if (min(size(vp))>0)
          tnr=segnr;
          for tri=1:1:size(fp,1)
            v0=vp(fp(tri,1),:);
            v1=vp(fp(tri,2),:);
            v2=vp(fp(tri,3),:);
            a=cross(v1-v0,v2-v0); %abs not necessary because the values are squared later
            param.objectsurfacearea(tnr)=param.objectsurfacearea(tnr)+sqrt(sum(a.*a))/2;
          end;
        end;
      end;
      
      segnr=segnr+1;
    end;
  end;
  
  if ((vdata.state.lastcancel==0)&&(vdata.data.exportobj.savesurfacestats==1))
    %write surface area values to text file
    fid = fopen([param.targetfolder vdata.data.exportobj.surfacestatsfile], 'wt');
    if (fid>0)
      fprintf(fid,'%% VastTools Surface Area Export\n');
      fprintf(fid,'%% Provided as-is, no guarantee for correctness!\n');
      fprintf(fid,'%% %s\n\n',get(vdata.fh,'name'));
      
      fprintf(fid,'%% Source File: %s\n',seglayername);
      fprintf(fid,'%% Mode: %s\n', vdata.data.exportobj.exportmodestring);
      fprintf(fid,'%% Area: (%d-%d, %d-%d, %d-%d)\n',rparam.xmin,rparam.xmax,rparam.ymin,rparam.ymax,rparam.zmin,rparam.zmax);
      fprintf(fid,'%% Computed at voxel size: (%f,%f,%f)\n',param.xscale*param.xunit*mipfact,param.yscale*param.yunit*mipfact,param.zscale*param.zunit*vdata.data.exportobj.slicestep);
      fprintf(fid,'%% Columns are: Object Name, Object ID, Surface Area in Export\n\n');
      for segnr=1:1:size(param.objects,1)
        seg=param.objects(segnr,1);
        fprintf(fid,'"%s"  %d  %f\n',name{seg},seg,param.objectsurfacearea(segnr));
      end;
      fprintf(fid,'\n');
      fclose(fid);
    end;
  end;
  
  if (vdata.state.lastcancel==0)
    set(vdata.ui.message,'String','Done.');
  else
    set(vdata.ui.message,'String','Canceled.');
  end;
  set(vdata.ui.cancelbutton,'Enable','off');
  vdata.state.lastcancel=0;
  

function name=getselectedseglayername()
  global vdata;
%   nrl=vdata.vast.getnroflayers();
%   found=0; l=0; name=[];
%   while ((found==0)&&(l<nrl))
%     linf=vdata.vast.getlayerinfo(l);
%     if (linf.type==1)
%       name=linf.name;
%       found=1;
%     end;
%     l=l+1;
%   end;
  
  [selectedlayernr, selectedemlayernr, selectedsegmentlayernr, res] = vdata.vast.getselectedlayernr();
  linf=vdata.vast.getlayerinfo(selectedsegmentlayernr);
  name=linf.name;
  

function [f,v]=mergemeshes(f1,v1,f2,v2)
  %mergemeshes.m
  %merges meshes defined by (f1,v1) and (f2,v2)
  %by Daniel Berger for MIT-BCS Seung, August 2011
  
  if (min(size(v1)))==0
    f=f2;
    v=v2;
    return;
  end;
  
  if (min(size(v2)))==0
    f=f1;
    v=v1;
    return;
  end;

  nrofvertices1=size(v1,1);
  nrofvertices2=size(v2,1);
  f2=f2+nrofvertices1;
  
  %find overlapping vertex region
  minv1=min(v1);
  maxv1=max(v1);
  minv2=min(v2);
  maxv2=max(v2);
  ovmin=max(minv1,minv2);
  ovmax=min(maxv1,maxv2);
  
  ov1=[(1:size(v1,1))' v1];
  ov1=ov1(((ov1(:,2)>=ovmin(1))&(ov1(:,2)<=ovmax(1))&(ov1(:,3)>=ovmin(2))&(ov1(:,3)<=ovmax(2))&(ov1(:,4)>=ovmin(3))&(ov1(:,4)<=ovmax(3))),:);
  ov2=[(1:size(v2,1))' v2];
  ov2=ov2(((ov2(:,2)>=ovmin(1))&(ov2(:,2)<=ovmax(1))&(ov2(:,3)>=ovmin(2))&(ov2(:,3)<=ovmax(2))&(ov2(:,4)>=ovmin(3))&(ov2(:,4)<=ovmax(3))),:);
  
  if (min(size(ov2))==0)
    %Non-overlapping objects
    f=[f1; f2];
    v=[v1; v2];
    return;
  end;

  %Link all vertices in v2 which have corresponding vertices in v1 to the v1 vertex
  deletevertex=zeros(nrofvertices2,1);
  facetouched=zeros(size(f2,1),3);
  oldcomparison=0;
  if (oldcomparison==1)
    for oi=1:1:size(ov1,1) %nrofvertices1
      i=ov1(oi,1);
      %This vertex is in the overlap zone. Find corresponding vertex in v2
      r2=find(ismember(ov2(:,2:4),v1(i,:),'rows'));
      i2=ov2(r2,1);
      
      %i is the index (row number) of the corresponding vertex in v1
      %i2 is the index (row number) of the corresponding vertex in v2
      %Exchange all occurences of this vertex in f2 with the vertex number used in f1
      facetouched(f2==i2+nrofvertices1)=1;
      f2(f2==i2+nrofvertices1)=i;
      deletevertex(i2)=1;
    end;
  else
    [c,i1a,i2a]=intersect(ov1(:,2:4),ov2(:,2:4),'rows');
    
%     bfacetouched=facetouched;
%     bf2=f2;
%     bdeletevertex=deletevertex;
    
    %Loopless version of loop below, should be faster
    aov1=ov1(i1a,1);
    aov2=ov2(i2a,1);
    kov2=aov2+nrofvertices1;
    [ism,locb]=ismember(f2,kov2);
    facetouched(ism)=1;
    f2(ism)=aov1(locb(ism));
    deletevertex(aov2)=1;
    
%     for oi=1:1:size(i1a,1)
%       i=ov1(i1a(oi),1);
%       i2=ov2(i2a(oi),1);
%       k=i2+nrofvertices1;
%       facetouched(f2==k)=1;
%       f2(f2==k)=i;
%       deletevertex(i2)=1;
%     end;
      
  end;

  %Delete the unused vertices in v2 and re-label the vertices in v2 accordingly
  %compute list of old and new vertex numbers
  z=[[1:nrofvertices1]'; zeros(size(deletevertex,1),1)];
  zp=nrofvertices1+1;
  for sp=1:1:size(deletevertex,1)
    if (deletevertex(sp)==0)
      z(nrofvertices1+sp)=zp;
      zp=zp+1;
    end;
  end;
  
  f2d=z(f2);

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % Delete duplicated faces from f2d
  facetouched=max(facetouched,[],2); %Flags for faces which had corners edited; only those might be duplicated
  pf2d=[(1:size(f2d,1))' sort(f2d,2)]; %Prefix for indexing
  pf2d=pf2d(facetouched==1,:); %Pick out only those faces from f2 which were changed
  sf2d=sortrows(pf2d,[2 3 4]);
  sf1=sortrows(sort(f1,2));
  
  r=ismember(sf2d(:,2:end),sf1,'rows');
  removeface=sf2d(r==1,1);
  v2d=v2(deletevertex==0,:);
  
  f=[f1; f2d];
  v=[v1; v2d];

  
function vertface2obj_mtllink_invnormal(v,f,filename,objectname,mtlfilename,materialname)
  % VERTFACE2OBJ Save a set of vertex coordinates and faces as a Wavefront/Alias Obj file
  % VERTFACE2OBJ(v,f,fname)
  %     v is a Nx3 matrix of vertex coordinates.
  %     f is a Mx3 matrix of vertex indices.
  %     fname is the filename to save the obj file.
  
  fid = fopen(filename,'wt');
  
  fprintf(fid,'mtllib %s\n',mtlfilename);
  fprintf(fid,'usemtl %s\n',materialname);
  
  for i=1:size(v,1)
    fprintf(fid,'v %f %f %f\n',v(i,1),v(i,2),v(i,3));
  end
  
  fprintf(fid,'g %s\n',objectname);
  
  for i=1:size(f,1);
    %2 1 3 order to flip normal
    fprintf(fid,'f %d %d %d\n',f(i,2),f(i,1),f(i,3));
  end
  fprintf(fid,'g\n');
  
  fclose(fid);
  
  
function vertface2obj_mtllink(v,f,filename,objectname,mtlfilename,materialname)
  % VERTFACE2OBJ Save a set of vertex coordinates and faces as a Wavefront/Alias Obj file
  % VERTFACE2OBJ(v,f,fname)
  %     v is a Nx3 matrix of vertex coordinates.
  %     f is a Mx3 matrix of vertex indices.
  %     fname is the filename to save the obj file.
  
  tic
  fid = fopen(filename,'wt');
  
  fprintf(fid,'mtllib %s\n',mtlfilename);
  fprintf(fid,'usemtl %s\n',materialname);
  
%   for i=1:size(v,1)
%     fprintf(fid,'v %f %f %f\n',v(i,1),v(i,2),v(i,3));
%   end
  
  for i=1:1000:size(v,1)
    str=[];
    for j=i:min([i+999 size(v,1)])
      str=[str sprintf('v %f %f %f\n',v(j,1),v(j,2),v(j,3))];
    end;
    if (min(size(str))>0)
      fprintf(fid,str);
    end;
  end
  
  fprintf(fid,'g %s\n',objectname);
  
%   for i=1:size(f,1);
%     fprintf(fid,'f %d %d %d\n',f(i,1),f(i,2),f(i,3));
%   end
  
  for i=1:1000:size(f,1)
    str=[];
    for j=i:min([i+999 size(f,1)])
      str=[str sprintf('f %d %d %d\n',f(j,1),f(j,2),f(j,3))];
    end;
    if (min(size(str))>0)
      fprintf(fid,str);
    end;
  end
  
  fprintf(fid,'g\n');
  
  fclose(fid);
  toc
  
  
function savematerialfile(filename,materialname,color,spec)
  %Define constant material parameters
  Ns=50.0000;
  Ni=1.5000;
  d=1.0000; %Opacity (0.0 is transparent, 1.0 is opaque)
  Tr=0.0000;
  Tf=[1.0000 1.0000 1.0000];
  illum=2;
  Ka=[0.0000 0.0000 0.0000];
  Kd=color;
  %Ks=[1.0000 1.0000 1.0000];
  Ks=[spec spec spec];
  Ke=[0.0000 0.0000 0.0000];
  
  %disp(sprintf('Saving %s ...',filename));
  fid = fopen(filename, 'wt');
  fprintf(fid,'# MTL writer by Daniel Berger, Jan 2015\n');
  fprintf(fid,'newmtl %s\n',materialname);
  fprintf(fid,'  Ns %.4f\n',Ns);
  fprintf(fid,'  Ni %.4f\n',Ni);
  fprintf(fid,'  d %.4f\n',d);
  fprintf(fid,'  Tr %.4f\n',Tr);
  fprintf(fid,'  Tf %.4f %.4f %.4f\n',Tf(1),Tf(2),Tf(3));
  fprintf(fid,'  illum %d\n',illum);
  fprintf(fid,'  Ka %.4f %.4f %.4f\n',Ka(1),Ka(2),Ka(3));
  fprintf(fid,'  Kd %.4f %.4f %.4f\n',Kd(1),Kd(2),Kd(3));
  fprintf(fid,'  Ks %.4f %.4f %.4f\n',Ks(1),Ks(2),Ks(3));
  fprintf(fid,'  Ke %.4f %.4f %.4f\n',Ke(1),Ke(2),Ke(3));
  fprintf(fid,'\n');
  fclose(fid);

function savetexturematerialfile(filename,materialname,color,spec,texturefilename)
  %Define constant material parameters
  Ns=50.0000;
  Ni=1.5000;
  d=1.0000; %Opacity (0.0 is transparent, 1.0 is opaque)
  Tr=0.0000;
  Tf=[1.0000 1.0000 1.0000];
  illum=2;
  Ka=[0.0000 0.0000 0.0000];
  Kd=color;
  Ks=[spec spec spec];
  Ke=[0.0000 0.0000 0.0000];
  
  %disp(sprintf('Saving %s ...',filename));
  fid = fopen(filename, 'wt');
  fprintf(fid,'# MTL writer by Daniel Berger, Jan 2015\n');
  fprintf(fid,'newmtl %s\n',materialname);
  fprintf(fid,'  Ns %.4f\n',Ns);
  fprintf(fid,'  Ni %.4f\n',Ni);
  fprintf(fid,'  d %.4f\n',d);
  fprintf(fid,'  Tr %.4f\n',Tr);
  fprintf(fid,'  Tf %.4f %.4f %.4f\n',Tf(1),Tf(2),Tf(3));
  fprintf(fid,'  illum %d\n',illum);
  fprintf(fid,'  Ka %.4f %.4f %.4f\n',Ka(1),Ka(2),Ka(3));
  fprintf(fid,'  Kd %.4f %.4f %.4f\n',Kd(1),Kd(2),Kd(3));
  fprintf(fid,'  Ks %.4f %.4f %.4f\n',Ks(1),Ks(2),Ks(3));
  fprintf(fid,'  Ke %.4f %.4f %.4f\n',Ke(1),Ke(2),Ke(3));
  fprintf(fid,'  map_Kd %s\n',texturefilename);
  fprintf(fid,'\n');
  fclose(fid);
  

function save3dsmaxloader(filename)
  fid = fopen(filename, 'wt');
  fprintf(fid,'files = getfiles ".\\*.obj"\n');
  fprintf(fid,'for f in files do (importfile (f) #noprompt)\n');
  fclose(fid);
  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Particle Cloud Exporting Functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [] = callback_exportparticles(varargin)
  global vdata;
  
  if (~checkconnection()) return; end;

  vinfo=vdata.vast.getinfo();
  
  if (min([vinfo.datasizex vinfo.datasizey vinfo.datasizez])==0)
    warndlg('ERROR: No volume open in VAST.','VastTools Particle Cloud exporting');
    return;
  end;
  
  %%Not needed because export from image stacks is now also possible
  nrofsegments=vdata.vast.getnumberofsegments();
  if (nrofsegments==0)
    warndlg('ERROR: No segmentation available in VAST.','VastTools Particle Cloud exporting');
    return;
  end;
  
  blockgui();
  
  %Display parameter dialog
  if (~isfield(vdata.data,'region'))
    vdata.data.region.xmin=0;
    vdata.data.region.xmax=vinfo.datasizex-1;
    vdata.data.region.ymin=0;
    vdata.data.region.ymax=vinfo.datasizey-1;
    vdata.data.region.zmin=0; %first slice
    vdata.data.region.zmax=vinfo.datasizez-1; %last slice
  else
    if (vdata.data.region.xmin<0) vdata.data.region.xmin=0; end;
    if (vdata.data.region.xmax>(vinfo.datasizex-1)) vdata.data.region.xmax=vinfo.datasizex-1; end;
    if (vdata.data.region.ymin<0) vdata.data.region.ymin=0; end;
    if (vdata.data.region.ymax>(vinfo.datasizey-1)) vdata.data.region.ymax=vinfo.datasizey-1; end;
    if (vdata.data.region.zmin<0) vdata.data.region.zmin=0; end; %first slice
    if (vdata.data.region.zmax>(vinfo.datasizez-1)) vdata.data.region.zmax=vinfo.datasizez-1; end;
  end;
  if (~isfield(vdata.data,'exportcloud'))
    vdata.data.exportcloud.miplevel=0;
    vdata.data.exportcloud.slicestep=1;     %4 means for example that every 4th slice exists (0, 4, 8, 12, ...)

    vdata.data.exportcloud.blocksizex=1024; %Data block size for processing. For small data sets, make this a bit larger than the data (otherwise objects may be open)
    vdata.data.exportcloud.blocksizey=1024;
    vdata.data.exportcloud.blocksizez=64;
    %vdata.data.exportcloud.overlap=1;     %Leave this at 1
    vdata.data.exportcloud.xscale=0.001;  %Use these to scale the exported models
    vdata.data.exportcloud.yscale=0.001;
    vdata.data.exportcloud.zscale=0.001;
    vdata.data.exportcloud.xunit=vinfo.voxelsizex;%6*4;  %in nm
    vdata.data.exportcloud.yunit=vinfo.voxelsizey; %6*4;  %in nm
    vdata.data.exportcloud.zunit=vinfo.voxelsizez; %30; %in nm
    vdata.data.exportcloud.outputoffsetx=0; %to translate the exported models in space
    vdata.data.exportcloud.outputoffsety=0;
    vdata.data.exportcloud.outputoffsetz=0;
    vdata.data.exportcloud.invertz=1;

    vdata.data.exportcloud.extractwhich=2;
    %vdata.data.exportcloud.objectcolors=1;
    vdata.data.exportcloud.sourcecoordmode=1;
    vdata.data.exportcloud.regionsizex=64; %Data block size for processing. For small data sets, make this a bit larger than the data (otherwise objects may be open)
    vdata.data.exportcloud.regionsizey=64;
    vdata.data.exportcloud.regionsizez=16;

    vdata.data.exportcloud.sourcemodelobj='';
    vdata.data.exportcloud.recentermodel=1;
    vdata.data.exportcloud.modelscale=1;
    
    vdata.data.exportcloud.targetfileprefix='Particles_';
    vdata.data.exportcloud.targetfolder=pwd;
    vdata.data.exportcloud.savecoords=1;
    vdata.data.exportcloud.coordsfilename='particle_coordinates.txt';
    vdata.data.exportcloud.includefoldernames=1;
    %vdata.data.exportcloud.closesurfaces=1;
    vdata.data.exportcloud.skipmodelgeneration=0;
    vdata.data.exportcloud.write3dsmaxloader=1;
    %vdata.data.exportcloud.savesurfacestats=0;
    %vdata.data.exportcloud.surfacestatsfile='surfacestats.txt';
  else
    if (vdata.data.exportcloud.miplevel>(vinfo.nrofmiplevels-1)) vdata.data.exportcloud.miplevel=vinfo.nrofmiplevels-1; end;
  end;
  
  scrsz = get(0,'ScreenSize');
  figheight=710;
  f = figure('units','pixels','position',[50 scrsz(4)-100-figheight 500 figheight],'menubar','none','numbertitle','off','name','VastTools - Export Particle Clouds as OBJ Files (3D Object Instancing)','resize','off');

  vpos=figheight-40;
 
  uicontrol('Style','text', 'Units','Pixels', 'Position',[20 vpos 120 15], 'Tag','t1','String','Source resolution:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  str=cell(vinfo.nrofmiplevels,1);
  vx=vinfo.voxelsizex;
  vy=vinfo.voxelsizey;
  vz=vinfo.voxelsizez;
  for i=1:1:vinfo.nrofmiplevels
    str{i}=sprintf('Mip %d - (%.2f nm, %.2f nm, %.2f nm) voxels',i-1,vx,vy,vz);
    vx=vx*2; vy=vy*2;
  end;
  pmh = uicontrol('Style','popupmenu','String',str,'Value',vdata.data.exportcloud.miplevel+1,'Position',[170 vpos 310 20]);
  vpos=vpos-30;

  uicontrol('Style','text', 'Units','Pixels', 'Position',[20 vpos 150 15],'String','Use every nth slice:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e1 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%d',vdata.data.exportcloud.slicestep),'horizontalalignment','left');
  vpos=vpos-40;
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[20 vpos 120 15],'String','Extract from area:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[340 vpos+10 140 20], 'String','Set to full', 'CallBack',{@callback_region_settofull,0});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[340 vpos-15 140 20], 'String','Set to selected bbox', 'CallBack',{@callback_region_settobbox,0});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[340 vpos-40 140 20], 'String','Set to current voxel', 'CallBack',{@callback_region_settocurrentvoxel,0});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[340 vpos-65 140 20], 'String','Extend to current voxel', 'CallBack',{@callback_region_extendtocurrentvoxel,0});
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[130 vpos 100 15],'String','X min:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_xmin = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%d', vdata.data.region.xmin),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[230 vpos 100 15],'String','X max:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_xmax = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[270 vpos 50 20],'String',sprintf('%d',vdata.data.region.xmax),'horizontalalignment','left');
  vpos=vpos-30;
  uicontrol('Style','text', 'Units','Pixels', 'Position',[130 vpos 100 15],'String','Y min:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_ymin = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%d',vdata.data.region.ymin),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[230 vpos 100 15],'String','Y max:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_ymax = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[270 vpos 50 20],'String',sprintf('%d',vdata.data.region.ymax),'horizontalalignment','left');
  vpos=vpos-30;
  uicontrol('Style','text', 'Units','Pixels', 'Position',[130 vpos 100 15],'String','Z min:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_zmin = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%d',vdata.data.region.zmin),'horizontalalignment','left');
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[230 vpos 100 15],'String','Z max:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_zmax = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[270 vpos 50 20],'String',sprintf('%d',vdata.data.region.zmax),'horizontalalignment','left');
  vpos=vpos-40;

  uicontrol('Style','text', 'Units','Pixels', 'Position',[20 vpos 150 15],'String','Voxel size (full res)  X:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e8 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%f', vdata.data.exportcloud.xunit),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[240 vpos 150 15],'String','Y:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e9 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[260 vpos 50 20],'String',sprintf('%f', vdata.data.exportcloud.yunit),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[330 vpos 150 15],'String','Z:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e10 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[350 vpos 50 20],'String',sprintf('%f', vdata.data.exportcloud.zunit),'horizontalalignment','left');
  vpos=vpos-20;
  uicontrol('Style','text', 'Units','Pixels', 'Position',[60 vpos 400 15], 'Tag','t1','String',sprintf('[VAST reports the voxel size to be: (%.2f nm, %.2f nm, %.2f nm)]',vinfo.voxelsizex,vinfo.voxelsizey,vinfo.voxelsizez),'backgroundcolor',get(f,'color'),'horizontalalignment','left');
  set(t,'tooltipstring','To change, enter the values in VAST under "Info / Volume properties" and save to your EM stack file.');
  vpos=vpos-30;
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[20 vpos 150 15],'String','Scale coordinates by X:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e11 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%f',vdata.data.exportcloud.xscale),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[240 vpos 150 15],'String','Y:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e12 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[260 vpos 50 20],'String',sprintf('%f',vdata.data.exportcloud.yscale),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[330 vpos 150 15],'String','Z:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e13 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[350 vpos 50 20],'String',sprintf('%f',vdata.data.exportcloud.zscale),'horizontalalignment','left');
  vpos=vpos-30;
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[20 vpos 150 15],'String','Model output offset   X:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e14 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%f',vdata.data.exportcloud.outputoffsetx),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[240 vpos 150 15],'String','Y:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e15 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[260 vpos 50 20],'String',sprintf('%f',vdata.data.exportcloud.outputoffsety),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[330 vpos 150 15],'String','Z:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e16 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[350 vpos 50 20],'String',sprintf('%f',vdata.data.exportcloud.outputoffsetz),'horizontalalignment','left');
  vpos=vpos-40;
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[20 vpos 150 15],'String','Processing block size   X:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e17 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%d',vdata.data.exportcloud.blocksizex),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[240 vpos 150 15],'String','Y:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e18 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[260 vpos 50 20],'String',sprintf('%d',vdata.data.exportcloud.blocksizey),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[330 vpos 150 15],'String','Z:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e19 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[350 vpos 50 20],'String',sprintf('%d',vdata.data.exportcloud.blocksizez),'horizontalalignment','left');
  vpos=vpos-40;

  uicontrol('Style','text', 'Units','Pixels', 'Position',[20 vpos 100 15], 'Tag','t1','String','Coords from:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  str=cell(4,1);
  str{1}='All segments individually, uncollapsed';
  str{2}='All segments, collapsed as in VAST';
  str{3}='Selected segment and children, uncollapsed';
  str{4}='Selected segment and children, collapsed as in VAST';
  pmh2 = uicontrol('Style','popupmenu','String',str,'Value',vdata.data.exportcloud.extractwhich,'Position',[120 vpos 290 20]);
  vpos=vpos-30;
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[20 vpos 100 15], 'Tag','t1','String','Coords mode:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  str=cell(3,1);
  str{1}='2D connected region centers (sections separately)';
  str{2}='3D connected region centers';
  str{3}='Anchor points of segments (ignores area above)';
  pmh3 = uicontrol('Style','popupmenu','String',str,'Value',vdata.data.exportcloud.sourcecoordmode,'Position',[120 vpos 290 20]);
  vpos=vpos-30;
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[20 vpos 220 15],'String','Max region diameter at selected mip level,  X:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e103 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[240 vpos 40 20],'String',sprintf('%d',vdata.data.exportcloud.regionsizex),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[290 vpos 50 15],'String','Y:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e104 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[305 vpos 40 20],'String',sprintf('%d',vdata.data.exportcloud.regionsizey),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[355 vpos 50 15],'String','Z:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e105 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[370 vpos 40 20],'String',sprintf('%d',vdata.data.exportcloud.regionsizez),'horizontalalignment','left');
  vpos=vpos-40;
 
  uicontrol('Style','text', 'Units','Pixels', 'Position',[20 vpos 100 15],'String','Source Model OBJ:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e101 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[120 vpos 290 20],'String',vdata.data.exportcloud.sourcemodelobj,'horizontalalignment','left');
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[420 vpos 60 20], 'String','Browse...', 'CallBack',{@callback_exportcloud_sourcemodelbrowse});
  vpos=vpos-30;
  
  c0 = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[120 vpos+5 100 15],'Value',vdata.data.exportcloud.recentermodel,'string','Recenter Model','backgroundcolor',get(f,'color')); 
  uicontrol('Style','text', 'Units','Pixels', 'Position',[240 vpos+4 120 15],'String','Rescale source model:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e102 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[360 vpos+2 50 20],'String',sprintf('%f',vdata.data.exportcloud.modelscale),'horizontalalignment','left');
  vpos=vpos-40;

  uicontrol('Style','text', 'Units','Pixels', 'Position',[20 vpos 130 15],'String','Target file name prefix:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e20 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[150 vpos 260 20],'String',vdata.data.exportcloud.targetfileprefix,'horizontalalignment','left');
  vpos=vpos-30;
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[20 vpos 100 15],'String','Target folder:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e21 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[120 vpos 290 20],'String',vdata.data.exportcloud.targetfolder,'horizontalalignment','left');
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[420 vpos 60 20], 'String','Browse...', 'CallBack',{@callback_exportcloud_browse});
  vpos=vpos-30;
  
  c01 = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[20 vpos 130 15],'Value',vdata.data.exportcloud.savecoords,'string','Save coordinates:','backgroundcolor',get(f,'color')); 
  vdata.temp.e22 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[150 vpos 260 20],'String',vdata.data.exportcloud.coordsfilename,'horizontalalignment','left');
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[420 vpos 60 20], 'String','Browse...', 'CallBack',{@callback_exportcloud_coordsfilenamebrowse});

  vpos=vpos-25;
  c1 = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[20 vpos 250 15],'Value',vdata.data.exportcloud.includefoldernames,'string','Include Vast folder names in file names','backgroundcolor',get(f,'color')); 
  c2 = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[300 vpos 200 15],'Value',vdata.data.exportcloud.invertz,'string','Invert Z axis','backgroundcolor',get(f,'color')); 
  vpos=vpos-25;
  %c3 = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[300 vpos 200 15],'Value',vdata.data.exportcloud.closesurfaces,'string','Close surface sides','backgroundcolor',get(f,'color')); 
  c4 = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[20 vpos 250 15],'Value',vdata.data.exportcloud.write3dsmaxloader,'string','Write 3dsMax bulk loader script to folder','backgroundcolor',get(f,'color')); 
  c5 = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[300 vpos 200 15],'Value',vdata.data.exportcloud.skipmodelgeneration,'string','Skip model file generation','backgroundcolor',get(f,'color')); 
  vpos=vpos-25;
  vpos=vpos-30;
  
  %c6 = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[30 vpos 250 15],'Value',vdata.data.exportcloud.savesurfacestats,'string','Save surface statistics to file:','backgroundcolor',get(f,'color')); 
  %e21 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[210 vpos 200 20],'String',vdata.data.exportcloud.surfacestatsfile,'horizontalalignment','left');
  
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[150 20 60 20], 'String','OK', 'CallBack',{@callback_done});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[290 20 60 20], 'String','Cancel', 'CallBack',{@callback_canceled});

  vdata.state.lastcancel=1;
  vdata.ui.temp.closefig=0;
  uiwait(f);
  
  if (vdata.state.lastcancel==0)
    vdata.data.exportcloud.miplevel=get(pmh,'value')-1;
    vdata.data.exportcloud.slicestep = str2num(get(e1,'String'));
    vdata.data.region.xmin = str2num(get(vdata.temp.e_xmin,'String'));
    vdata.data.region.xmax = str2num(get(vdata.temp.e_xmax,'String'));
    vdata.data.region.ymin = str2num(get(vdata.temp.e_ymin,'String'));
    vdata.data.region.ymax = str2num(get(vdata.temp.e_ymax,'String'));
    vdata.data.region.zmin = str2num(get(vdata.temp.e_zmin,'String'));
    vdata.data.region.zmax = str2num(get(vdata.temp.e_zmax,'String'));
    
    vdata.data.exportcloud.xunit = str2num(get(e8,'String'));
    vdata.data.exportcloud.yunit = str2num(get(e9,'String'));
    vdata.data.exportcloud.zunit = str2num(get(e10,'String'));
    vdata.data.exportcloud.xscale = str2num(get(e11,'String'));
    vdata.data.exportcloud.yscale = str2num(get(e12,'String'));
    vdata.data.exportcloud.zscale = str2num(get(e13,'String'));
    vdata.data.exportcloud.outputoffsetx = str2num(get(e14,'String'));
    vdata.data.exportcloud.outputoffsety = str2num(get(e15,'String'));
    vdata.data.exportcloud.outputoffsetz = str2num(get(e16,'String'));
    vdata.data.exportcloud.blocksizex = str2num(get(e17,'String'));
    vdata.data.exportcloud.blocksizey = str2num(get(e18,'String'));
    vdata.data.exportcloud.blocksizez = str2num(get(e19,'String'));

    vdata.data.exportcloud.extractwhich=get(pmh2,'value');
    str=get(pmh2,'string'); vdata.data.exportcloud.exportmodestring=str{vdata.data.exportcloud.extractwhich};
    vdata.data.exportcloud.sourcecoordmode=get(pmh3,'value');
    str=get(pmh3,'string'); vdata.data.exportcloud.coordmodestring=str{vdata.data.exportcloud.sourcecoordmode};
    %vdata.data.exportcloud.objectcolors=get(pmh3,'value');
    vdata.data.exportcloud.regionsizex=str2num(get(vdata.temp.e103,'String'));
    vdata.data.exportcloud.regionsizey=str2num(get(vdata.temp.e104,'String'));
    vdata.data.exportcloud.regionsizez=str2num(get(vdata.temp.e105,'String'));
    
    vdata.data.exportcloud.recentermodel=get(c0,'value');
    vdata.data.exportcloud.modelscale=str2num(get(vdata.temp.e102,'String'));
    
    vdata.data.exportcloud.targetfileprefix=get(e20,'String');
    vdata.data.exportcloud.targetfolder=get(vdata.temp.e21,'String');
    vdata.data.exportcloud.savecoords = get(c01,'value');
    vdata.data.exportcloud.includefoldernames = get(c1,'value');
    vdata.data.exportcloud.invertz = get(c2,'value');
    %vdata.data.exportcloud.closesurfaces = get(c3,'value');
    vdata.data.exportcloud.write3dsmaxloader = get(c4,'value');
    vdata.data.exportcloud.skipmodelgeneration = get(c5,'value');
    
    %vdata.data.exportcloud.savesurfacestats = get(c6,'value');
    %vdata.data.exportcloud.surfacestatsfile = get(e21,'String');
    
    vdata.data.exportcloud.targetfolder=get(vdata.temp.e21,'String');
    vdata.data.exportcloud.coordsfilename=get(vdata.temp.e22,'String');
  end;
  
  if (vdata.ui.temp.closefig==1) %to distinguish close on button press and close on window x
    close(f);
  end;

  if (vdata.state.lastcancel==0)
    
%     if (vdata.data.exportcloud.objectcolors==2)
%       if (~isfield(vdata.data,'measurevol'))
%         warndlg('ERROR: To use segment volume colors, please compute volumes first ("Measure / Measure Segment Volumes" in the main menu)!','VastTools Particle Cloud exporting');
%         releasegui();
%         return;
%       end;
%       if (~isfield(vdata.data.measurevol,'lastvolume'))
%         warndlg('ERROR: To use segment volume colors, please compute volumes first ("Measure / Measure Segment Volumes" in the main menu)!','VastTools Particle Cloud exporting');
%         releasegui();
%         return;
%       end;
%     end;
    
    if ((vdata.data.exportcloud.targetfolder(end)~='/')&&(vdata.data.exportcloud.targetfolder(end)~='\'))
      vdata.data.exportcloud.targetfolder=[vdata.data.exportcloud.targetfolder '/'];
    end;
    
    if ((vdata.data.exportcloud.xunit==0)||(vdata.data.exportcloud.yunit==0)||(vdata.data.exportcloud.zunit==0))
      res = questdlg(sprintf('Warning: The voxel size is set to (%f,%f,%f) which will result in collapsed models. Are you sure you want to continue?',vdata.data.exportcloud.xunit,vdata.data.exportcloud.yunit,vdata.data.exportcloud.zunit),'Export 3D Surfaces as OBJ Files','Yes','No','Yes');
      if strcmp(res,'No')
        releasegui();
        return; 
      end
    end;
    
    exportparticles();
  end;  
  releasegui();  
  
  
function [] = exportparticles()
  global vdata;
  
  if (~checkconnection()) return; end;
  set(vdata.ui.cancelbutton,'Enable','on');
  
  param=vdata.data.exportcloud;
  rparam=vdata.data.region;
  
  %Load source model file
  set(vdata.ui.message,'String',{'Exporting Particle Clouds ...','Loading source model ...'});
  pause(0.1);
  if (param.skipmodelgeneration==0)
    if (min(size(param.sourcemodelobj))==0)
      warndlg('ERROR: No 3D model file selected.','Loading source model failed!');
      set(vdata.ui.message,'String','Aborted.');
      set(vdata.ui.cancelbutton,'Enable','off');
      vdata.state.lastcancel=0;
      return;
    end;
    [v,f]=loadawobj(param.sourcemodelobj,0);
    if ((size(v,2)==0)||(size(f,2)==0))
      warndlg([sprintf('ERROR: %d vertices and %d triangles found in "',size(v,2),size(f,2)) vdata.data.exportcloud.sourcemodelobj '". Aborting.'],'Loading source model failed!');
      set(vdata.ui.message,'String','Aborted.');
      set(vdata.ui.cancelbutton,'Enable','off');
      vdata.state.lastcancel=0;
      return;
    end;
    fmax=max(f(:));
    
    if (param.recentermodel==1)
      tv=mean(v,2)*ones(1,size(v,2));
      v=v-tv;
    end;
    if (param.modelscale~=1)
      v=v*param.modelscale;
    end;
  end;

  set(vdata.ui.message,'String',{'Exporting Particle Clouds ...','Loading Metadata ...'});
  pause(0.1);

  [data,res] = vdata.vast.getallsegmentdatamatrix();
  [name,res] = vdata.vast.getallsegmentnames();
  seglayername=getselectedseglayername();
  name(1)=[]; %remove 'Background'
  maxobjectnumber=max(data(:,1));
  
  xmin=bitshift(rparam.xmin,-param.miplevel);
  xmax=bitshift(rparam.xmax,-param.miplevel)-1;
  ymin=bitshift(rparam.ymin,-param.miplevel);
  ymax=bitshift(rparam.ymax,-param.miplevel)-1;
  zmin=rparam.zmin;
  zmax=rparam.zmax;
  mipfact=bitshift(1,param.miplevel);
  
  % Compute full name (including folder names) from name and hierarchy
  if (param.includefoldernames==1)
    fullname=name;
    for i=1:1:size(data,1)
      j=i;
      while data(j,14)~=0 %Check if parent is not 0
        j=data(j,14);
        fullname{i}=[name{j} '.' fullname{i}];
      end;
    end;
    name=fullname;
  end;
  
  % Compute list of objects to export
  switch param.extractwhich
    case 1  %All segments individually, uncollapsed
      objects=uint32([data(:,1) data(:,2)]);
      vdata.vast.setsegtranslation([],[]);
      
    case 2  %All segments, collapsed as in Vast
      %4: Collapse segments as in the view during segment text file exporting
      objects=unique(data(:,18));
      objects=uint32([objects data(objects,2)]);
      vdata.vast.setsegtranslation(data(:,1),data(:,18));
      
    case 3  %Selected segment and children, uncollapsed
      selected=find(bitand(data(:,2),65536)>0);
      if (min(size(selected))==0)
        objects=uint32([data(:,1) data(:,2)]);
      else
        selected=[selected getchildtreeids(data,selected)];
        objects=uint32([selected' data(selected,2)]);
      end;
      vdata.vast.setsegtranslation(data(selected,1),data(selected,1));
      
    case 4  %Selected segment and children, collapsed as in Vast
      selected=find(bitand(data(:,2),65536)>0);
      if (min(size(selected))==0)
        %None selected: choose all, collapsed
        selected=data(:,1);
        objects=unique(data(:,18));
      else
        selected=[selected getchildtreeids(data,selected)];
        objects=unique(data(selected,18));
      end;
      
      objects=uint32([objects data(objects,2)]);
      vdata.vast.setsegtranslation(data(selected,1),data(selected,18));
  end;

  seg=cell(size(objects,1),1);
  for s=1:length(seg)
    seg{s}.id=objects(s,1);
    seg{s}.name=name{objects(s,1)};
    seg{s}.colors=data(objects(s,1),3:5);
    seg{s}.coords=[];
    seg{s}.volumes=[];
  end;
  
  %Compute list of coordinates
  set(vdata.ui.message,'String',{'Exporting Particle Clouds ...','Computing particle coordinates ...'});
  pause(0.1);
  switch param.sourcecoordmode
    case 1 % 2D connected regions
      seg=computeareacoords(seg,2);
      for s=1:length(seg)
        vp=seg{s}.coords; %ordered XYZ
        seg{s}.coordspix=vp;
        if (min(size(vp))>0)
          vp(:,1)=vp(:,1)*param.xscale*param.xunit; %*mipfact;
          vp(:,2)=vp(:,2)*param.yscale*param.yunit; %*mipfact;
          vp(:,3)=vp(:,3)*param.zscale*param.zunit;
        end;
        seg{s}.coords=vp;
      end;
    case 2 % 3D connected regions
      seg=computeareacoords(seg,3);
      for s=1:length(seg)
        vp=seg{s}.coords; %ordered XYZ
        seg{s}.coordspix=vp;
        if (min(size(vp))>0)
          vp(:,1)=vp(:,1)*param.xscale*param.xunit; %*mipfact;
          vp(:,2)=vp(:,2)*param.yscale*param.yunit; %*mipfact;
          vp(:,3)=vp(:,3)*param.zscale*param.zunit;
        end;
        seg{s}.coords=vp;
      end;
    case 3 % Anchor points
      for s=1:length(seg)
        vp=data(objects(s,1),11:13);
        seg{s}.coordspix=vp;
        if (min(size(vp))>0)
          vp(:,1)=vp(:,1)*param.xscale*param.xunit; %*mipfact;
          vp(:,2)=vp(:,2)*param.yscale*param.yunit; %*mipfact;
          vp(:,3)=vp(:,3)*param.zscale*param.zunit;
        end;
        seg{s}.coords=vp;
        seg{s}.volumes=zeros(size(vp,1),1);
      end;
  end;
  vdata.vast.setsegtranslation([],[]);
  
  %Write 3dsmax bulk loader script
  if ((param.write3dsmaxloader==1)&&(vdata.state.lastcancel==0))
    save3dsmaxloader([param.targetfolder 'loadallobj_here.ms']);
  end;
  
  if ((param.skipmodelgeneration==0)&&(vdata.state.lastcancel==0))
    %Build particle cloud models and save
    set(vdata.ui.message,'String',{'Exporting Particle Clouds ...','Saving particle cloud models ...'});
    pause(0.1);
    
    for s=1:length(seg)
      if (vdata.state.lastcancel==0)
        sid=seg{s}.id;
        vcoordsmu=seg{s}.coords;
        
        if (min(size(vcoordsmu))>0)
          %invert Z axis if requested
          if (param.invertz==1)
            if (size(vcoordsmu,1)>0)
              vcoordsmu(:,3)=-vcoordsmu(:,3);
            end;
          end;
          
          vp=[]; fp=[];
          vpp=1; fpp=0;
          for j=1:1:size(vcoordsmu,1)
            vcenter=vcoordsmu(j,:);
            vcenter=[vcenter(2) vcenter(1) vcenter(3)]'; %swapping x and y flips object to correct shape but 90 deg rotated
            lv=v+vcenter*ones(1,size(v,2));
            lf=f+fpp;
            vp=[vp lv]; %append new vertices
            fp=[fp lf]; %append new faces
            fpp=fpp+fmax;
          end;
          
          vp=vp';
          fp=fp';
          
          %add offset if requested
          if (param.outputoffsety~=0)
            vp(:,1)=vp(:,1)+param.outputoffsety;
          end;
          if (param.outputoffsetx~=0)
            vp(:,2)=vp(:,2)+param.outputoffsetx;
          end;
          if (param.outputoffsetz~=0)
            vp(:,3)=vp(:,3)+param.outputoffsetz;
          end;
          
          on=seg{s}.name;
          on(on==' ')='_';
          on(on=='?')='_';
          on(on=='*')='_';
          on(on=='\')='_';
          on(on=='/')='_';
          on(on=='|')='_';
          on(on==':')='_';
          on(on=='"')='_';
          on(on=='<')='_';
          on(on=='>')='_';
          filename=[param.targetfolder param.targetfileprefix sprintf('_%04d_%s.obj',sid,on)];
          objectname=[param.targetfileprefix sprintf('_%04d_%s',sid,seg{s}.name)];
          mtlfilename=[param.targetfileprefix sprintf('_%04d_%s.mtl',sid,on)];
          mtlfilenamewithpath=[filename(1:end-3) 'mtl'];
          materialname=[param.targetfileprefix sprintf('_%04d_material',sid)];
          
          set(vdata.ui.message,'String',{'Exporting Surfaces ...', ['Saving ' filename ' as Wavefront OBJ.....']});
          pause(0.01);
          
          %if (vdata.data.exportcloud.invertz==1)
          vertface2obj_mtllink(vp,fp,filename,objectname,mtlfilename,materialname);
          %else
          %  vertface2obj_mtllink_invnormal(vp,fp,filename,objectname,mtlfilename,materialname);
          %end;
          
          savematerialfile(mtlfilenamewithpath,materialname,seg{s}.colors/255,1.0);
          
          %disp(['Saving ' lparam.filename ' as Wavefront OBJ.....']);
          %vertface2obj(vp',fp',lparam.filename,lparam.objectname);
        end;
      end;
    end;
  end;

  if ((vdata.data.exportcloud.savecoords==1)&&(vdata.state.lastcancel==0))
    %write surface area values to text file
    voxsizex=param.xunit*mipfact;
    voxsizey=param.yunit*mipfact;
    voxsizez=param.zunit;
    voxelvol=voxsizex*voxsizey*voxsizez;
    
    fid = fopen(vdata.data.exportcloud.coordsfilename, 'wt');
    if (fid>0)
      fprintf(fid,'%% VastTools Particle Cloud Exporter Coordinates File\n');
      fprintf(fid,'%% Provided as-is, no guarantee for correctness!\n');
      fprintf(fid,'%% %s\n\n',get(vdata.fh,'name'));
      
      fprintf(fid,'%% Source File: %s\n',getselectedseglayername());
      fprintf(fid,'%% Export Mode: %s\n', vdata.data.exportcloud.exportmodestring);
      fprintf(fid,'%% Coordinate Extraction Mode: %s\n', vdata.data.exportcloud.coordmodestring);
      fprintf(fid,'%% Area: (%d-%d, %d-%d, %d-%d)\n',vdata.data.region.xmin,vdata.data.region.xmax,vdata.data.region.ymin,vdata.data.region.ymax,vdata.data.region.zmin,vdata.data.region.zmax);
      fprintf(fid,'%% Volume computed at voxel size: (%f,%f,%f)\n',voxsizex,voxsizey,voxsizez);
      fprintf(fid,'%% Columns are: Object Name, Object ID, Region Nr, Pixel Coord X, Y, Z, Exported Coord X, Y, Z, Voxel Count, Region Volume\n\n');

      for s=1:length(seg)
        c=seg{s}.coords;
        p=seg{s}.coordspix;
        v=seg{s}.volumes;
        for r=1:size(seg{s}.coords,1)
          fprintf(fid,'"%s"  %d  %d  %d %d %d  %f %f %f  %d %f\n',seg{s}.name,seg{s}.id,r, p(r,1),p(r,2),p(r,3), c(r,1),c(r,2),c(r,3), v(r), v(r)*voxelvol);
        end;
      end;
      fprintf(fid,'\n');
      fclose(fid);
    else
       warndlg(['WARNING: Could not open "' vdata.data.exportcloud.coordsfilename '" for writing.'],'Saving coordinates file failed!');
    end;
    
  end;
  
  if (vdata.state.lastcancel==0)
    set(vdata.ui.message,'String','Done.');
  else
    set(vdata.ui.message,'String','Canceled.');
  end;
  set(vdata.ui.cancelbutton,'Enable','off');
  vdata.state.lastcancel=0;
  
  
function [] = callback_exportcloud_sourcemodelbrowse(varargin)
  global vdata;
  [filename, pathname] = uigetfile({'*.obj';'*.*'},'Select source OBJ file for instancing', vdata.data.exportcloud.sourcemodelobj);
  if (filename~=0)
    set(vdata.temp.e101,'String',[pathname filename]);
    vdata.data.exportcloud.sourcemodelobj=[pathname filename];
    [v,f]=loadawobj(vdata.data.exportcloud.sourcemodelobj,0);
    if ((size(v,2)==0)||(size(f,2)==0))
      warndlg([sprintf('ERROR: %d vertices and %d triangles found in "',size(v,2),size(f,2)) vdata.data.exportcloud.sourcemodelobj '".'],'Loading source model failed!');
      set(vdata.temp.e101,'String','');
      vdata.data.exportcloud.sourcemodelobj='';
    else
      msgbox({['Parsing of "' vdata.data.exportcloud.sourcemodelobj '" successful.']; sprintf('%d vertices and %d triangles found.',size(v,2),size(f,2))},'Loading source model succeeded','help');
    end;
  end;
  
function [] = callback_exportcloud_browse(varargin)
  global vdata;
  foldername = uigetdir(vdata.data.exportcloud.targetfolder,'VastTools - Select target folder for OBJ files:');
  if (foldername~=0)
    set(vdata.temp.e21,'String',foldername);
    vdata.data.exportcloud.targetfolder=foldername;
  end;
  
function [] = callback_exportcloud_coordsfilenamebrowse(varargin)
  global vdata;
  [filename, pathname] = uiputfile({'*.txt';'*.*'},'Select target file for coordinates file:', vdata.data.exportcloud.coordsfilename);
  if (filename~=0)
    set(vdata.temp.e22,'String',[pathname filename]);
    vdata.data.exportcloud.coordsfilename=[pathname filename];
  end;
  
  
function [V,F3,F4]=loadawobj(modelname,opts)
  % loadawobj
  % Load an Wavefront/Alias obj style model. Will only consider polygons with 3 or 4 vertices.
  % Adapted from W.S. Harwin, University Reading, 2006,2010. Matlab BSD license; thanks also to Doug Hackett
  V=[]; F3=[]; F4=[];

  fid = fopen(modelname,'r');
  if (fid<0) return; end;
  
  vnum=1; f3num=1; f4num=1; vtnum=1; vnnum=1; g3num=1; g4num=1; Vtmp=[];

  % Line by line passing of the obj file
  while ~feof(fid)
    Ln=fgets(fid);
    Ln=strtrim(Ln);
    Ln=strrep(Ln,'       ',' '); % 8-2 .. 12-6
    Ln=strrep(Ln,'    ',' '); % 5-2 6-3 4-1
    Ln=strrep(Ln,'  ',' '); % 3-2 2-1
    Ln=strrep(Ln,'  ',' ');
    Ln=strrep(Ln,char([13 10]),''); % remove cr/lf
    Ln=strrep(Ln,char([10]),''); % remove lf
    
    objtype=sscanf(Ln,'%s',1);
    l=length(Ln);
    if l==0
      continue
    end

    switch objtype
      case '#' % comment
      case 'v' % vertex
        v=sscanf(Ln(2:end),'%f');
        Vtmp(:,vnum)=v;
        vnum=vnum+1;
      case 'vt'	% textures
        if vtnum==1
          vtnum=vtnum+1;
        end
      case 'g' % sub mesh
        g3num=[g3num f3num];
        g4num=[g4num f4num];
      case 'mtllib' % material library
      case 'usemtl' % use this material name
      case 'l' % Line
      case 's' %smooth shading across polygons
      case 'vn' % normals
        if vnnum==1
          vnnum=vnnum+1;
        end
      case 'f' % faces
        nvrts=length(findstr(Ln,' ')); % spaces as a predictor of n vertices
        slashpat=findstr(Ln,'/');
        nslash=length(slashpat);
        if nslash >1 % dblslash can be 0, 1 or >1
          dblslash=slashpat(2)-slashpat(1); else dblslash=0;
        end
        Ln=Ln(3:end); % get rid of the f
        if nslash == 0 % Face = vertex
          f1=sscanf(Ln,'%f');
        elseif nslash == nvrts && dblslash>1 % Face = v/tc
          data1=sscanf(Ln,'%f/%f');
          if nvrts == 3
            f1=data1([1 3 5]);
            tc1=data1([2 4 6]);
          end
          if nvrts == 4;
            f1=data1([1 3 5 7]);
            tc1=data1([2 4 6 8]);
          end
        elseif nslash == 2*nvrts && dblslash==1 % v//n
          data1=sscanf(Ln,'%f//%f');
          if nvrts == 3
            f1=data1([1 3 5]);
            vn1=data1([2 4 6]);
            Vn3(:,f3num)=f1;
          end
          if nvrts == 4;
            f1=data1([1 3 5 7]);
            vn11=data1([2 4 6 8]);
            Vn4(:,f4num)=f1;
          end
        elseif nslash == 2*nvrts && dblslash>1 % v/tc/n
          data1=sscanf(Ln,'%f/%f/%f');
          if nvrts == 3
            f1=data1([1 4 7]);
            tc1=data1([2 5 8]);
            vn1=data1([3 6 9]);
            Vn3(:,f3num)=f1;
          end
          if nvrts == 4;
            f1=data1([1 4 7 10]);
            tc1=data1([2 5 8 11]);
            vn1=data1([3 6 9 12]);
            Vn4(:,f4num)=f1;
          end
        end
        % Now put the data into the array(s)
        if nvrts == 3
          F3(:,f3num)=f1;
          f3num=f3num+1;
        elseif nvrts ==4
          F4(:,f4num)=f1;
          f4num=f4num+1;
        else
          %warning(sprintf('v nvrts=%d %s',nvrts, Ln));
        end
      otherwise
        %disp(['unprocessed-' Ln '-']); % see what has not been processed
    end
  end
  fclose(fid);
  V=Vtmp;
  

function seg = computeareacoords(seg,dim)
  %dim 2: 2D (XY); 3: 3D
  global vdata;
  
  param=vdata.data.exportcloud;
  rparam=vdata.data.region;
  
  xmin=bitshift(rparam.xmin,-param.miplevel);
  xmax=bitshift(rparam.xmax,-param.miplevel)-1;
  ymin=bitshift(rparam.ymin,-param.miplevel);
  ymax=bitshift(rparam.ymax,-param.miplevel)-1;
  zmin=rparam.zmin;
  zmax=rparam.zmax;
  mipfact=bitshift(1,param.miplevel);
  
  % Compute number of blocks in volume
  nrxtiles=0; tilex1=xmin;
  while (tilex1<=xmax)
    tilex1=tilex1+param.blocksizex; %-param.overlap;
    nrxtiles=nrxtiles+1;
  end;
  nrytiles=0; tiley1=ymin;
  while (tiley1<=ymax)
    tiley1=tiley1+param.blocksizey; %-param.overlap;
    nrytiles=nrytiles+1;
  end;
  nrztiles=0; tilez1=zmin;
  if (param.slicestep==1)
    slicenumbers=zmin:zmax;
    while (tilez1<=zmax)
      tilez1=tilez1+param.blocksizez; %-param.overlap;
      nrztiles=nrztiles+1;
    end;
  else
    slicenumbers=zmin:param.slicestep:zmax;
    nrztiles=ceil(size(slicenumbers,2)/param.blocksizez); %(param.blocksizez-param.overlap));
    j=1;
    %for p=1:param.blocksizez-param.overlap:size(slicenumbers,2)
    for p=1:param.blocksizez:size(slicenumbers,2)
      pe=min([p+param.blocksizez-1 size(slicenumbers,2)]);
      blockslicenumbers{j}=slicenumbers(p:pe);
      
      rb=p-param.regionsizez;
      if (rb<1) rb=1; end;
      re=pe+param.regionsizez;
      if (re>size(slicenumbers,2)) re=size(slicenumbers,2); end;
      rblockslicenumbers{j}=slicenumbers(rb:re);
      j=j+1;
    end;
    
  end;
  param.nrxtiles=nrxtiles; param.nrytiles=nrytiles; param.nrztiles=nrztiles;
  
  tilez1=zmin; tz=1;
  while ((tz<=nrztiles)&&(vdata.state.lastcancel==0))
    tilez2=tilez1+param.blocksizez-1;
    if (tilez2>zmax) tilez2=zmax; end;
    tilezs=tilez2-tilez1+1;
    
    if (dim==2)
      %No Z-padding needed if 2D XY sections are analyzed individually
      regz1=tilez1;
      regz2=tilez2;
      regzs=tilezs;
      minzborder=0;
    else
      regz1=tilez1-param.regionsizez;
      if (regz1<zmin) regz1=zmin; end;
      regz2=tilez2+param.regionsizez;
      if (regz2>zmax) regz2=zmax; end;
      regzs=regz2-regz1+1;
      minzborder=tilez1-regz1;
    end;
    
    tiley1=ymin; ty=1;
    while ((ty<=nrytiles)&&(vdata.state.lastcancel==0))
      tiley2=tiley1+param.blocksizey-1;
      if (tiley2>ymax) tiley2=ymax; end;
      tileys=tiley2-tiley1+1;
      
      regy1=tiley1-param.regionsizey;
      if (regy1<ymin) regy1=ymin; end;
      regy2=tiley2+param.regionsizey;
      if (regy2>ymax) regy2=ymax; end;
      regys=regy2-regy1+1;
      minyborder=tiley1-regy1;
      
      tilex1=xmin; tx=1;
      while ((tx<=nrxtiles)&&(vdata.state.lastcancel==0))
        tilex2=tilex1+param.blocksizex-1;
        if (tilex2>xmax) tilex2=xmax; end;
        tilexs=tilex2-tilex1+1;
        
        regx1=tilex1-param.regionsizex;
        if (regx1<xmin) regx1=xmin; end;
        regx2=tilex2+param.regionsizex;
        if (regx2>xmax) regx2=xmax; end;
        regxs=regx2-regx1+1;
        minxborder=tilex1-regx1;

        if (dim==2)
          message={'Identifying 2D Regions ...',sprintf('Loading Segmentation Cube (%d,%d,%d) of (%d,%d,%d)...',tx,ty,tz,nrxtiles,nrytiles,nrztiles)};
        else
          message={'Identifying 3D Regions ...',sprintf('Loading Segmentation Cube (%d,%d,%d) of (%d,%d,%d)...',tx,ty,tz,nrxtiles,nrytiles,nrztiles)};
        end;
        set(vdata.ui.message,'String',message);
        pause(0.01);
        %Read this cube
        if (param.slicestep==1)
          %[segimage,values,numbers,bboxes,res] = vdata.vast.getsegimageRLEdecodedbboxes(param.miplevel,tilex1,tilex2,tiley1,tiley2,tilez1,tilez2,0);
          [segimage,values,numbers,bboxes,res] = vdata.vast.getsegimageRLEdecodedbboxes(param.miplevel,regx1,regx2,regy1,regy2,regz1,regz2,0,1);
        else
          bs=rblockslicenumbers{tz};
          segimage=uint16(zeros(regx2-regx1+1,regy2-regy1+1,size(bs,2)));
          numarr=int32(zeros(maxobjectnumber,1));
          bboxarr=zeros(maxobjectnumber,6)-1;
          firstblockslice=bs(1);
          for i=1:1:size(bs,2)
            [ssegimage,svalues,snumbers,sbboxes,res] = vdata.vast.getsegimageRLEdecodedbboxes(param.miplevel,regx1,regx2,regy1,regy2,bs(i),bs(i),0,1);
            segimage(:,:,i)=ssegimage;
            snumbers(svalues==0)=[];
            sbboxes(svalues==0,:)=[];
            sbboxes(:,[3 6])=sbboxes(:,[3 6])+i-1;
            svalues(svalues==0)=[];
            if (min(size(svalues))>0)
              numarr(svalues)=numarr(svalues)+snumbers;
              bboxarr(svalues,:)=vdata.vast.expandboundingboxes(bboxarr(svalues,:),sbboxes);
            end;
          end;
          values=find(numarr>0);
          numbers=numarr(values);
          bboxes=bboxarr(values,:);
        end;
        
        %Find all separate regions with centers in block core
        if (dim==2)
          message={'Identifying 2D Regions ...',sprintf('2D Connected Component Analysis in (%d,%d,%d) of (%d,%d,%d)...',tx,ty,tz,nrxtiles,nrytiles,nrztiles)};
          set(vdata.ui.message,'String',message);
          pause(0.01);
          for slice=1:size(segimage,3)
            img=squeeze(segimage(:,:,slice));
            for s=1:length(seg)
              id=seg{s}.id;
              [l,num]=bwlabeln(img==id,4);

              for n=1:num
                idx=find(l==n);
                [y,x]=ind2sub(size(img),idx);
                c=[round(mean(y))-minyborder round(mean(x))-minxborder slice];
                %check whether center c is within the inner cube
                if ((c(1)>0)&&(c(2)>0)&&(c(3)>0)&&(c(1)<=param.blocksizey)&&(c(2)<=param.blocksizex)&&(c(3)<=param.blocksizez))
                  c=c+[tiley1-1 tilex1-1 -1];
                  c=c.*[mipfact mipfact param.slicestep];
                  c=c+[0 0 tilez1];
                  seg{s}.coords=[seg{s}.coords; c];
                  seg{s}.volumes=[seg{s}.volumes; length(idx)];
                else
                  %not in inner cube, don't process
                end;
              end;
            end;
          end;
        else
          message={'Identifying 3D Regions ...',sprintf('3D Connected Component Analysis in (%d,%d,%d) of (%d,%d,%d)...',tx,ty,tz,nrxtiles,nrytiles,nrztiles)};
          set(vdata.ui.message,'String',message);
          pause(0.01);
          for s=1:length(seg)
            id=seg{s}.id;
            [l,num]=bwlabeln(segimage==id,6);
            for n=1:num
              idx=find(l==n);
              [y,x,z]=ind2sub(size(segimage),idx);
              c=[round(mean(y))-minyborder round(mean(x))-minxborder round(mean(z))-minzborder];
              %check whether center c is within the inner cube
              if ((c(1)>0)&&(c(2)>0)&&(c(3)>0)&&(c(1)<=param.blocksizey)&&(c(2)<=param.blocksizex)&&(c(3)<=param.blocksizez))
                c=c+[tiley1-1 tilex1-1 -1];
                c=c.*[mipfact mipfact param.slicestep];
                c=c+[0 0 tilez1];
                seg{s}.coords=[seg{s}.coords; c];
                seg{s}.volumes=[seg{s}.volumes; length(idx)];
              else
                %not in inner cube, don't process
              end;
            end;
          end;
        end;
        
        tilex1=tilex1+param.blocksizex; %-param.overlap;
        tx=tx+1;
      end;
      tiley1=tiley1+param.blocksizey; %-param.overlap;
      ty=ty+1;
    end;
    tilez1=tilez1+param.blocksizez; %-param.overlap;
    tz=tz+1;
  end;
  for s=1:length(seg)
    if (min(size(seg{s}.coords))>0)
      seg{s}.coords=[seg{s}.coords(:,2) seg{s}.coords(:,1) seg{s}.coords(:,3)]; %make XYZ
    end;
  end;
  
  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Box and Scale Bar Exporting Functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [] = callback_exportbox(varargin)
  global vdata;
  
  if (~checkconnection()) return; end;
  vinfo=vdata.vast.getinfo();
  if (min([vinfo.datasizex vinfo.datasizey vinfo.datasizez])==0)
    warndlg('ERROR: No volume open in VAST.','VastTools OBJ exporting');
    return;
  end;
  
  blockgui();
  
  %Display parameter dialog
  if (~isfield(vdata.data,'region'))
    vdata.data.region.xmin=0;
    vdata.data.region.xmax=vinfo.datasizex-1;
    vdata.data.region.ymin=0;
    vdata.data.region.ymax=vinfo.datasizey-1;
    vdata.data.region.zmin=0; %first slice
    vdata.data.region.zmax=vinfo.datasizez-1; %last slice
  else
    if (vdata.data.region.xmin<0) vdata.data.region.xmin=0; end;
    if (vdata.data.region.xmax>(vinfo.datasizex-1)) vdata.data.region.xmax=vinfo.datasizex-1; end;
    if (vdata.data.region.ymin<0) vdata.data.region.ymin=0; end;
    if (vdata.data.region.ymax>(vinfo.datasizey-1)) vdata.data.region.ymax=vinfo.datasizey-1; end;
    if (vdata.data.region.zmin<0) vdata.data.region.zmin=0; end; %first slice
    if (vdata.data.region.zmax>(vinfo.datasizez-1)) vdata.data.region.zmax=vinfo.datasizez-1; end;
  end;
  if (~isfield(vdata.data,'exportbox'))
    vdata.data.exportbox.xscale=0.001;  %Use these to scale the exported models
    vdata.data.exportbox.yscale=0.001;
    vdata.data.exportbox.zscale=0.001;
    vdata.data.exportbox.xunit=vinfo.voxelsizex;%6*4;  %in nm
    vdata.data.exportbox.yunit=vinfo.voxelsizey; %6*4;  %in nm
    vdata.data.exportbox.zunit=vinfo.voxelsizez; %30; %in nm
    vdata.data.exportbox.outputoffsetx=0; %to translate the exported models in space
    vdata.data.exportbox.outputoffsety=0;
    vdata.data.exportbox.outputoffsetz=0;
    vdata.data.exportbox.invertnormals=0;
    vdata.data.exportbox.invertz=1;
    vdata.data.exportbox.style=1;
    vdata.data.exportbox.wireframewidth=1; %microns
    vdata.data.exportbox.boxcolor=[1 1 1];
    vdata.data.exportbox.miplevel=0;
    vdata.data.exportbox.slicestep=1;
  end;
  
  scrsz = get(0,'ScreenSize');
  figheight=480;
  f = figure('units','pixels','position',[50 scrsz(4)-100-figheight 420 figheight],'menubar','none','numbertitle','off','name','VastTools - Export 3D Box as OBJ File','resize','off');
  pos = get(f,'position');
  ax = axes('units','pix','outerposition',[0 0 pos([3 4])],'position',[0 0 pos([3 4])],'parent',f,'visible','off','xlim',[0 pos(3)],'ylim',[0 pos(4)]);
  vpos=figheight-30;

  uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 120 15],'String','Box Coordinates:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vpos=vpos-30;

  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[260 vpos+10 140 20], 'String','Set to full', 'CallBack',{@callback_region_settofull,0});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[260 vpos-15 140 20], 'String','Set to selected bbox', 'CallBack',{@callback_region_settobbox,0});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[260 vpos-40 140 20], 'String','Set to current voxel', 'CallBack',{@callback_region_settocurrentvoxel,0});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[260 vpos-65 140 20], 'String','Extend to current voxel', 'CallBack',{@callback_region_extendtocurrentvoxel,0});
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 100 15],'String','X min:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_xmin = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[70 vpos 50 20],'String',sprintf('%d', vdata.data.region.xmin),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[130 vpos 100 15],'String','X max:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_xmax = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%d',vdata.data.region.xmax),'horizontalalignment','left');
  vpos=vpos-30;
  uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 100 15],'String','Y min:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_ymin = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[70 vpos 50 20],'String',sprintf('%d',vdata.data.region.ymin),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[130 vpos 100 15],'String','Y max:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_ymax = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%d',vdata.data.region.ymax),'horizontalalignment','left');
  vpos=vpos-30;
  uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 100 15],'String','Z min:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_zmin = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[70 vpos 50 20],'String',sprintf('%d',vdata.data.region.zmin),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[130 vpos 100 15],'String','Z max:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_zmax = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%d',vdata.data.region.zmax),'horizontalalignment','left');
  vpos=vpos-40;

  uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 150 15],'String','Voxel size (full res)  X:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e8 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%f', vdata.data.exportbox.xunit),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[240 vpos 150 15],'String','Y:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e9 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[260 vpos 50 20],'String',sprintf('%f', vdata.data.exportbox.yunit),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[330 vpos 150 15],'String','Z:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e10 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[350 vpos 50 20],'String',sprintf('%f', vdata.data.exportbox.zunit),'horizontalalignment','left');
  vpos=vpos-20;
  t=uicontrol('Style','text', 'Units','Pixels', 'Position',[60 vpos 400 15], 'Tag','t1','String',sprintf('[VAST reports the voxel size to be: (%.2f nm, %.2f nm, %.2f nm)]',vinfo.voxelsizex,vinfo.voxelsizey,vinfo.voxelsizez),'backgroundcolor',get(f,'color'),'horizontalalignment','left');
  set(t,'tooltipstring','To change, enter the values in VAST under "Info / Volume properties" and save to your EM stack file.');
  vpos=vpos-30;
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 150 15],'String','Scale models by   X:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e11 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%f',vdata.data.exportbox.xscale),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[240 vpos 150 15],'String','Y:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e12 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[260 vpos 50 20],'String',sprintf('%f',vdata.data.exportbox.yscale),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[330 vpos 150 15],'String','Z:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e13 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[350 vpos 50 20],'String',sprintf('%f',vdata.data.exportbox.zscale),'horizontalalignment','left');
  vpos=vpos-30;
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 150 15],'String','Model output offset   X:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e14 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%f',vdata.data.exportbox.outputoffsetx),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[240 vpos 150 15],'String','Y:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e15 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[260 vpos 50 20],'String',sprintf('%f',vdata.data.exportbox.outputoffsety),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[330 vpos 150 15],'String','Z:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e16 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[350 vpos 50 20],'String',sprintf('%f',vdata.data.exportbox.outputoffsetz),'horizontalalignment','left');
  vpos=vpos-40;
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 100 15], 'String','Box style:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  str=cell(3,1);
  str{1}='Wireframe';
  str{2}='Solid-color surfaces';
  str{3}='Textured surfaces (VAST screenshot images)';
  vdata.temp.e_style = uicontrol('Style','popupmenu','String',str,'Value',vdata.data.exportbox.style,'Position',[130 vpos 270 20],'CallBack',{@callback_box_setstyle});
  vpos=vpos-30;
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 90 15],'String','Box Color:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_colorbox = patch('xdata',[130 149 149 130],'ydata',[vpos+1 vpos+1 vpos+20 vpos+20],'facecolor',vdata.data.exportbox.boxcolor,'parent',ax);
  vdata.temp.e_setcolor = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[160 vpos 30 20], 'String','Set', 'CallBack',{@callback_box_setcolor,1});

  uicontrol('Style','text', 'Units','Pixels', 'Position',[250 vpos 90 15],'String','Wireframe width:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_wireframewidth = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[350 vpos 50 20],'String',sprintf('%f',vdata.data.exportbox.wireframewidth),'horizontalalignment','left');
  vpos=vpos-30;
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 100 15],'String','Texture resolution:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  str=cell(vinfo.nrofmiplevels,1);
  vx=vinfo.voxelsizex;
  vy=vinfo.voxelsizey;
  vz=vinfo.voxelsizez;
  for i=1:1:vinfo.nrofmiplevels
    str{i}=sprintf('Mip %d - (%.2f nm, %.2f nm, %.2f nm) voxels',i-1,vx,vy,vz);
    vx=vx*2; vy=vy*2;
  end;
  vdata.temp.e_miplevel = uicontrol('Style','popupmenu','String',str,'Value',vdata.data.exportbox.miplevel+1,'Position',[130 vpos 270 20]);
  vpos=vpos-30;

  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 150 15],'String','Use every nth slice:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_slicestep = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[130 vpos 50 20],'String',sprintf('%d',vdata.data.exportbox.slicestep),'horizontalalignment','left');
  vpos=vpos-40;
  
  c1 = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[30 vpos 130 15],'Value',vdata.data.exportbox.invertnormals,'string','Invert Normals','backgroundcolor',get(f,'color'));
  c2 = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[170 vpos 130 15],'Value',vdata.data.exportbox.invertz,'string','Invert Z axis','backgroundcolor',get(f,'color')); 
  
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[110 20 60 20], 'String','OK', 'CallBack',{@callback_done});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[250 20 60 20], 'String','Cancel', 'CallBack',{@callback_canceled});

  vdata.state.lastcancel=1;
  vdata.ui.temp.closefig=0;
  callback_box_setstyle();
  uiwait(f);
  
  if (vdata.state.lastcancel==0)
    vdata.data.region.xmin = str2num(get(vdata.temp.e_xmin,'String'));
    vdata.data.region.xmax = str2num(get(vdata.temp.e_xmax,'String'));
    vdata.data.region.ymin = str2num(get(vdata.temp.e_ymin,'String'));
    vdata.data.region.ymax = str2num(get(vdata.temp.e_ymax,'String'));
    vdata.data.region.zmin = str2num(get(vdata.temp.e_zmin,'String'));
    vdata.data.region.zmax = str2num(get(vdata.temp.e_zmax,'String'));
    
    vdata.data.exportbox.xunit = str2num(get(e8,'String'));
    vdata.data.exportbox.yunit = str2num(get(e9,'String'));
    vdata.data.exportbox.zunit = str2num(get(e10,'String'));
    vdata.data.exportbox.xscale = str2num(get(e11,'String'));
    vdata.data.exportbox.yscale = str2num(get(e12,'String'));
    vdata.data.exportbox.zscale = str2num(get(e13,'String'));
    vdata.data.exportbox.outputoffsetx = str2num(get(e14,'String'));
    vdata.data.exportbox.outputoffsety = str2num(get(e15,'String'));
    vdata.data.exportbox.outputoffsetz = str2num(get(e16,'String'));

    vdata.data.exportbox.style=get(vdata.temp.e_style,'value');
    vdata.data.exportbox.wireframewidth = str2num(get(vdata.temp.e_wireframewidth,'String'));
    vdata.data.exportbox.miplevel = get(vdata.temp.e_miplevel,'value')-1;
    vdata.data.exportbox.slicestep = floor(str2num(get(vdata.temp.e_slicestep,'String')));
    vdata.data.exportbox.invertnormals = get(c1,'value');
    vdata.data.exportbox.invertz = get(c2,'value');
  end;
  
  if (vdata.ui.temp.closefig==1) %to distinguish close on button press and close on window x
    close(f);
  end;

  if (vdata.state.lastcancel==0)
    if ((vdata.data.exportbox.xunit==0)||(vdata.data.exportbox.yunit==0)||(vdata.data.exportbox.zunit==0))
      res = questdlg(sprintf('Warning: The voxel size is set to (%f,%f,%f) which will result in a zero-sized model. Are you sure you want to continue?',vdata.data.exportbox.xunit,vdata.data.exportbox.yunit,vdata.data.exportbox.zunit),'Export 3D Box as OBJ File','Yes','No','Yes');
      if strcmp(res,'No')
        releasegui();
        return; 
      end
    end;
    
    %Check if this is a single plane
    planedir=[0 0 0];
    if (vdata.data.region.xmin==vdata.data.region.xmax) planedir(1)=1; end;
    if (vdata.data.region.ymin==vdata.data.region.ymax) planedir(2)=1; end;
    if (vdata.data.region.zmin==vdata.data.region.zmax) planedir(3)=1; end;
    if (sum(planedir)>1)
      warndlg('ERROR: Zero volume box and not a plane. Aborting.','Export 3D Box as OBJ File');
      releasegui();
      return; 
    end;
    
    if (sum(planedir)==1)
      if (vdata.data.exportbox.style==1)
        warndlg('ERROR: Wireframe planes are currently not supported. To export a wireframe model please define a nonplanar box. Aborting.','Export 3D Box as OBJ File');
        releasegui();
        return;
      end;
      
      %Export a single plane
      planeo=planedir(1)+2*planedir(2)+3*planedir(3); %convert to single number
      %get filename to save plane
      switch planeo
      case 1
        targetfilename='yzplane.obj';
      case 2
        targetfilename='xzplane.obj';
      case 3
        targetfilename='xyplane.obj';
      end;
      [filename, pathname] = uiputfile({'*.obj';'*.*'},'Export 3D Plane as OBJ File - Select target file name',targetfilename);
      if (filename==0)
        %'Cancel' was pressed. Don't save.
        releasegui();
        return;
      end;
      
      set(vdata.ui.cancelbutton,'Enable','on');
      set(vdata.ui.message,'String','Exporting Plane Model ...');
      pause(0.1);
      
      cornercoords=[vdata.data.region.xmin vdata.data.region.ymin vdata.data.region.zmin vdata.data.region.xmax vdata.data.region.ymax vdata.data.region.zmax];
      voxelsize=[vdata.data.exportbox.xunit vdata.data.exportbox.yunit vdata.data.exportbox.zunit];
      boxfilename=[pathname filename];
      objectname=filename(1:end-4);
      materialname=[objectname '_mtl'];
      materialfilenamewithpath=[boxfilename(1:end-4) '.mtl'];
      materialfilename=[materialname(1:end-4) '.mtl'];
      objectcolor=vdata.data.exportbox.boxcolor;
      flipnormals=vdata.data.exportbox.invertnormals;
      invert_z=vdata.data.exportbox.invertz;
      wireframewidth=vdata.data.exportbox.wireframewidth;
      miplevel=vdata.data.exportbox.miplevel;
      slicestep=vdata.data.exportbox.slicestep;
      
      vtx=zeros(4,3);
      v=1;
      for z=0:1-planedir(3)
        for y=0:1-planedir(2)
          for x=0:1-planedir(1)
            vtx(v,1)=cornercoords(x*3+1)*voxelsize(1)*vdata.data.exportbox.xscale+vdata.data.exportbox.outputoffsetx;
            vtx(v,2)=cornercoords(y*3+2)*voxelsize(2)*vdata.data.exportbox.yscale+vdata.data.exportbox.outputoffsety;
            vtx(v,3)=cornercoords(z*3+3)*voxelsize(3)*vdata.data.exportbox.zscale+vdata.data.exportbox.outputoffsetz;
            if (invert_z==1)
              vtx(v,3)=-vtx(v,3);
            end;
            v=v+1;
          end;
        end;
      end;
      
      usetexture=0;
      
      switch vdata.data.exportbox.style
      case 1 %Wireframe
        %this is caught before, so this case should never be reached here
      case 2 %Solid color
        quad=[1 2 4 3]; %clockwise
          
      case 3 %Screenshots texture
        quad=[1 2 4 3]; %clockwise
        quadt=[1 2 4 3]; %clockwise
        usetexture=1;
        
        %Compute texture dimensions
        xmin=bitshift(vdata.data.region.xmin,-vdata.data.exportbox.miplevel);
        xmax=bitshift(vdata.data.region.xmax,-vdata.data.exportbox.miplevel)-1;
        ymin=bitshift(vdata.data.region.ymin,-vdata.data.exportbox.miplevel);
        ymax=bitshift(vdata.data.region.ymax,-vdata.data.exportbox.miplevel)-1;
        zsections=vdata.data.region.zmin:vdata.data.exportbox.slicestep:vdata.data.region.zmax;
        tsizex=(xmax-xmin+1);
        tsizey=(ymax-ymin+1);
        tsizez=length(zsections);
        
        
        
        set(vdata.ui.message,'String',{'Exporting Textured Plane Model ...','Loading Texture ...'});
        pause(0.1);
        
        switch planeo
        case 1 %YZ-plane
          texwidth=tsizey;
          texheight=tsizez;
          [scsimage,res] = vdata.vast.getscreenshotimage(miplevel,xmin,xmin,ymin,ymax,zsections(1),zsections(end),1);
          scsimage=squeeze(scsimage);
          scsimage=scsimage(:,zsections-zsections(1)+1,:);
          scsimage=permute(scsimage,[2 1 3]);
          %scsimage=flipdim(scsimage,2);
          boxtex=scsimage;
          tc=[[1 0]; [1 1]; [0 0]; [0 1]];
          
        case 2 %XZ-plane
          texwidth=tsizex;
          texheight=tsizez;
          [scsimage,res] = vdata.vast.getscreenshotimage(miplevel,xmin,xmax,ymin,ymin,zsections(1),zsections(end),1);
          scsimage=squeeze(scsimage);
          scsimage=scsimage(:,zsections-zsections(1)+1,:);
          scsimage=permute(scsimage,[2 1 3]);
          %scsimage=flipdim(scsimage,1);
          boxtex=scsimage;
          tc=[[1 0]; [1 1]; [0 0]; [0 1]];
          
        case 3 %XY-plane
          texwidth=tsizex;
          texheight=tsizey;
          [scsimage,res] = vdata.vast.getscreenshotimage(miplevel,xmin,xmax,ymin,ymax,zsections(1),zsections(1),1);
          boxtex=scsimage;
          tc=[[1 0]; [1 1]; [0 0]; [0 1]];
        end;

        if (vdata.state.lastcancel==0)
%           % Extend texture edges by 1 pixel to remove texture edge issues
%           boxtex(1:tsizez,tsizez,:)=boxtex(1:tsizez,tsizez+1,:);
%           boxtex(1:tsizez,tsizez+tsizex+1,:)=boxtex(1:tsizez,tsizez+tsizex,:);
%           boxtex(tsizez+tsizey+1:tsizez+tsizey+tsizez,tsizez,:)=boxtex(tsizez+tsizey+1:tsizez+tsizey+tsizez,tsizez+1,:);
%           boxtex(tsizez+tsizey+1:tsizez+tsizey+tsizez,tsizez+tsizex+1,:)=boxtex(tsizez+tsizey+1:tsizez+tsizey+tsizez,tsizez+tsizex,:);
%           
%           boxtex(tsizez,1:tsizez,:)=boxtex(tsizez+1,1:tsizez,:);
%           boxtex(tsizez+tsizey+1,1:tsizez,:)=boxtex(tsizez+tsizey,1:tsizez,:);
%           boxtex(tsizez,tsizez+tsizex+1:end,:)=boxtex(tsizez+1,tsizez+tsizex+1:end,:);
%           boxtex(tsizez+tsizey+1,tsizez+tsizex+1:end,:)=boxtex(tsizez+tsizey,tsizez+tsizex+1:end,:);
          
          texfilename=[objectname '.png'];
          set(vdata.ui.message,'String',{'Exporting Textured Box Model ...',['Saving Texture ' pathname texfilename ' ...']});
          pause(0.1);
          imwrite(boxtex,[pathname texfilename]);
        end;
        
      end;
        
        
      if (vdata.state.lastcancel==0)
        if (usetexture==0)
          %%%% Write to file
          fid = fopen(boxfilename,'wt');
          fprintf(fid,'mtllib %s\n',materialfilename);
          fprintf(fid,'usemtl %s\n',materialname);
          
          for i=1:size(vtx,1)
            fprintf(fid,'v %f %f %f\n',vtx(i,2),vtx(i,1),vtx(i,3));
          end;
          fprintf(fid,'g %s\n',objectname);
          
          for i=1:size(quad,1);
            if (flipnormals==0)
              %1 4 3 2 order
              fprintf(fid,'f %d %d %d %d\n',quad(i,1),quad(i,4),quad(i,3),quad(i,2));
            else
              %1 2 3 4 order
              fprintf(fid,'f %d %d %d %d\n',quad(i,1),quad(i,2),quad(i,3),quad(i,4));
            end;
          end
          fprintf(fid,'g\n');
          fclose(fid);
          
          savematerialfile(materialfilenamewithpath, materialname, objectcolor, 0.0);
        else
          % With texture - generate texture coordinates and add reference to texture file
          %%%% Write to file
          fid = fopen(boxfilename,'wt');
          fprintf(fid,'mtllib %s\n',materialfilename);
          fprintf(fid,'usemtl %s\n',materialname);
          
          for i=1:size(vtx,1)
            fprintf(fid,'v %f %f %f\n',vtx(i,2),vtx(i,1),vtx(i,3));
          end;
          for i=1:size(tc,1)
            fprintf(fid,'vt %f %f\n',tc(i,2),tc(i,1));
          end;
          fprintf(fid,'g %s\n',objectname);
          
          for i=1:size(quad,1);
            if (flipnormals==0)
              %1 4 3 2 order
              fprintf(fid,'f %d/%d %d/%d %d/%d %d/%d\n',quad(i,1),quadt(i,1),quad(i,4),quadt(i,4),quad(i,3),quadt(i,3),quad(i,2),quadt(i,2));
            else
              %1 2 3 4 order
              fprintf(fid,'f %d/%d %d/%d %d/%d %d/%d\n',quad(i,1),quadt(i,1),quad(i,2),quadt(i,2),quad(i,3),quadt(i,3),quad(i,4),quadt(i,4));
            end;
          end
          fprintf(fid,'g\n');
          fclose(fid);
          
          savetexturematerialfile(materialfilenamewithpath, materialname, objectcolor, 0.0, texfilename);
        end;
      end;
      
      if (vdata.state.lastcancel==0)
        set(vdata.ui.message,'String','Done.');
      else
        set(vdata.ui.message,'String','Canceled.');
      end;
      set(vdata.ui.cancelbutton,'Enable','off');
      vdata.state.lastcancel=0;
      releasegui();
      return;
    end;
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %The following is for exporting 3D boxes
    
    %get filename to save box
    targetfilename='box.obj';
    [filename, pathname] = uiputfile({'*.obj';'*.*'},'Export 3D Box as OBJ File - Select target file name',targetfilename);
    if (filename==0)
      %'Cancel' was pressed. Don't save.
      releasegui();
      return;
    end;
    
    set(vdata.ui.cancelbutton,'Enable','on');
    set(vdata.ui.message,'String','Exporting Box Model ...');
    pause(0.1);
    
    cornercoords=[vdata.data.region.xmin vdata.data.region.ymin vdata.data.region.zmin vdata.data.region.xmax vdata.data.region.ymax vdata.data.region.zmax];
    voxelsize=[vdata.data.exportbox.xunit vdata.data.exportbox.yunit vdata.data.exportbox.zunit];
    boxfilename=[pathname filename];
    objectname=filename(1:end-4);
    materialname=[objectname '_mtl'];
    materialfilenamewithpath=[boxfilename(1:end-4) '.mtl'];
    materialfilename=[materialname(1:end-4) '.mtl'];
    objectcolor=vdata.data.exportbox.boxcolor;
    flipnormals=vdata.data.exportbox.invertnormals;
    invert_z=vdata.data.exportbox.invertz;
    wireframewidth=vdata.data.exportbox.wireframewidth;
    miplevel=vdata.data.exportbox.miplevel;
    slicestep=vdata.data.exportbox.slicestep;
    
    vtx=zeros(8,3);
    v=1;
    for z=0:1
      for y=0:1
        for x=0:1
          vtx(v,1)=cornercoords(x*3+1)*voxelsize(1)*vdata.data.exportbox.xscale+vdata.data.exportbox.outputoffsetx;
          vtx(v,2)=cornercoords(y*3+2)*voxelsize(2)*vdata.data.exportbox.yscale+vdata.data.exportbox.outputoffsety;
          vtx(v,3)=cornercoords(z*3+3)*voxelsize(3)*vdata.data.exportbox.zscale+vdata.data.exportbox.outputoffsetz;
          if (invert_z==1)
            vtx(v,3)=-vtx(v,3);
          end;
          v=v+1;
        end;
      end;
    end;
    
    
    usetexture=0;
    
    switch vdata.data.exportbox.style
      case 1 %Wireframe
        quad=[... % outer polygons
          [0 5 5+1 0+1]; [5 15 15+1 5+1]; [15 10 10+1 15+1]; [10 0 0+1 10+1]; ...
          [10 15 15+2 10+2]; [15 35 35+2 15+2]; [35 30 30+2 35+2]; [30 10 10+2 30+2]; ...
          [15 5 5+3 15+3]; [5 25 25+3 5+3]; [25 35 35+3 25+3]; [35 15 15+3 35+3]; ...
          [5 0 0+2 5+2]; [0 20 20+2 0+2]; [20 25 25+2 20+2]; [25 5 5+2 25+2]; ...
          [0 10 10+3 0+3]; [10 30 30+3 10+3]; [30 20 20+3 30+3]; [20 0 0+3 20+3]; ...
          [30 35 35+1 30+1]; [35 25 25+1 35+1]; [25 20 20+1 25+1]; [20 30 30+1 20+1];...
          ... %inner polygons
          [0+1 5+1 5+4 0+4]; [5+1 15+1 15+4 5+4]; [15+1 10+1 10+4 15+4]; [10+1 0+1 0+4 10+4]; ...
          [10+2 15+2 15+4 10+4]; [15+2 35+2 35+4 15+4]; [35+2 30+2 30+4 35+4]; [30+2 10+2 10+4 30+4]; ...
          [15+3 5+3 5+4 15+4]; [5+3 25+3 25+4 5+4]; [25+3 35+3 35+4 25+4]; [35+3 15+3 15+4 35+4]; ...
          [5+2 0+2 0+4 5+4]; [0+2 20+2 20+4 0+4]; [20+2 25+2 25+4 20+4]; [25+2 5+2 5+4 25+4]; ...
          [0+3 10+3 10+4 0+4]; [10+3 30+3 30+4 10+4]; [30+3 20+3 20+4 30+4]; [20+3 0+3 0+4 20+4]; ...
          [30+1 35+1 35+4 30+4]; [35+1 25+1 25+4 35+4]; [25+1 20+1 20+4 25+4]; [20+1 30+1 30+4 20+4]];
        quad=quad+1;
        
        %%%% Prepare vertex coords
        pvtx=[[0 0 0]; [1 1 0]; [1 0 -1]; [0 1 -1]; [1 1 -1]]*wireframewidth;
        tvtx=pvtx;
        vtx2=zeros(size(vtx,1)*5,3);
        v=0;
        for z=0:1
          if (z>0)
            tvtx(:,3)=-pvtx(:,3);
          else
            tvtx(:,3)=pvtx(:,3);
          end;
          for y=0:1
            if (y>0)
              tvtx(:,2)=-pvtx(:,2);
            else
              tvtx(:,2)=pvtx(:,2);
            end;
            for x=0:1
              if (x>0)
                tvtx(:,1)=-pvtx(:,1);
              else
                tvtx(:,1)=pvtx(:,1);
              end;
              for j=1:5
                vtx2(v*5+j,:)=vtx(v+1,:)+tvtx(j,:);
              end;
              v=v+1;
            end;
          end;
        end;
        vtx=vtx2;
        
      case 2 %Solid color
        quad=[[1 2 4 3]; [3 4 8 7]; [4 2 6 8]; [2 1 5 6]; [1 3 7 5]; [7 8 6 5]]; %clockwise
        
      case 3 %Screenshots texture
        quad=[[1 2 4 3]; [3 4 8 7]; [4 2 6 8]; [2 1 5 6]; [1 3 7 5]; [7 8 6 5]]; %clockwise
        quadt=[[1 2 4 3]; [21 22 24 23]; [19 17 18 20]; [12 11 9 10]; [14 16 15 13]; [7 8 6 5]]; %clockwise
        usetexture=1;
        
        %Compute texture dimensions
        xmin=bitshift(vdata.data.region.xmin,-vdata.data.exportbox.miplevel);
        xmax=bitshift(vdata.data.region.xmax,-vdata.data.exportbox.miplevel)-1;
        ymin=bitshift(vdata.data.region.ymin,-vdata.data.exportbox.miplevel);
        ymax=bitshift(vdata.data.region.ymax,-vdata.data.exportbox.miplevel)-1;
        zsections=vdata.data.region.zmin:vdata.data.exportbox.slicestep:vdata.data.region.zmax;
        tsizex=(xmax-xmin+1);
        tsizey=(ymax-ymin+1);
        tsizez=length(zsections);
        texwidth=2*tsizex+2*tsizez;
        texheight=tsizey+2*tsizez;
    
%         %Define texture coordinates for all box corners in pixels as (y,x) - (righthanded coords)
%         tc=[[tsizez+1 tsizez+1]; [tsizez+1 tsizez+tsizex]; [tsizez+tsizey tsizez+1]; [tsizez+tsizey tsizez+tsizex]; ... %top
%             [tsizez+1 tsizez*2+tsizex*2]; [tsizez+1 tsizez*2+tsizex+1]; [tsizez+tsizey tsizez*2+tsizex*2]; [tsizez+tsizey tsizez*2+tsizex+1]; ... %bottom
%             [1 tsizez+1]; [1 tsizez+tsizex]; [tsizez tsizez+1]; [tsizez tsizez+tsizex]; ... %back
%             [tsizez+1 1]; [tsizez+1 tsizez]; [tsizez+tsizey 1]; [tsizez+tsizey tsizez]; ... %left
%             [tsizez+1 tsizez+tsizex+1]; [tsizez+1 tsizez+tsizex+tsizez]; [tsizez+tsizey tsizez+tsizex+1]; [tsizez+tsizey tsizez+tsizex+tsizez]; ... %right
%             [tsizez+tsizey+1 tsizez+1]; [tsizez+tsizey+1 tsizez+tsizex]; [tsizez+tsizey+tsizez tsizez+1]; [tsizez+tsizey+tsizez tsizez+tsizex]]; %front
        
        %Define texture coordinates for all box corners in pixels as (y,x) - (lefthanded coords)
        tc=[[tsizez+tsizey tsizez+1]; [tsizez+tsizey tsizez+tsizex]; [tsizez+1 tsizez+1]; [tsizez+1 tsizez+tsizex];  ... %top
            [tsizez+tsizey tsizez*2+tsizex*2]; [tsizez+tsizey tsizez*2+tsizex+1]; [tsizez+1 tsizez*2+tsizex*2]; [tsizez+1 tsizez*2+tsizex+1]; ... %bottom
            [tsizez+tsizey+tsizez tsizez+1]; [tsizez+tsizey+tsizez tsizez+tsizex]; [tsizez+tsizey+1 tsizez+1]; [tsizez+tsizey+1 tsizez+tsizex];  ... %front
            [tsizez+tsizey 1]; [tsizez+tsizey tsizez]; [tsizez+1 1]; [tsizez+1 tsizez];  ... %left
            [tsizez+tsizey tsizez+tsizex+1]; [tsizez+tsizey tsizez+tsizex+tsizez]; [tsizez+1 tsizez+tsizex+1]; [tsizez+1 tsizez+tsizex+tsizez];  ... %right
            [tsizez tsizez+1]; [tsizez tsizez+tsizex]; [1 tsizez+1]; [1 tsizez+tsizex]]; %back
          
        tc(:,1)=(tc(:,1)-1)/(texheight-1);
        tc(:,2)=(tc(:,2)-1)/(texwidth-1);
        
        %Proxy texture to test mapping
        boxtex=zeros(texheight,texwidth,3,'uint8');
        boxtex(tsizez+1:tsizez+tsizey,tsizez+1:tsizez+tsizex,1)=255;
        boxtex(tsizez+1:tsizez+tsizey,tsizez+tsizex+tsizez+1:tsizez+tsizex+tsizez+tsizex,2)=255;
        boxtex(1:tsizez,tsizez+1:tsizez+tsizex,1:2)=255;
        boxtex(tsizez+tsizey+1:tsizez+tsizey+tsizez,tsizez+1:tsizez+tsizex,3)=255;
        boxtex(tsizez+1:tsizez+tsizey,1:tsizez,[1 3])=255;
        boxtex(tsizez+1:tsizez+tsizey,tsizez+tsizex+1:tsizez+tsizex+tsizez,[2 3])=255;
        
        if (vdata.state.lastcancel==0)
          set(vdata.ui.message,'String',{'Exporting Textured Box Model ...','Loading Texture 1/6 ...'});
          pause(0.1);
          [scsimage,res] = vdata.vast.getscreenshotimage(miplevel,xmin,xmax,ymin,ymax,zsections(1),zsections(1),1);
          %scsimage=permute(scsimage,[2 1 3 4]);
          boxtex(tsizez+1:tsizez+tsizey,tsizez+1:tsizez+tsizex,:)=scsimage;
        end;
          
        if (vdata.state.lastcancel==0)
          set(vdata.ui.message,'String',{'Exporting Textured Box Model ...','Loading Texture 2/6 ...'});
          pause(0.1);
          [scsimage,res] = vdata.vast.getscreenshotimage(miplevel,xmin,xmax,ymin,ymax,zsections(end),zsections(end),1);
          scsimage=flipdim(scsimage,2);
          boxtex(tsizez+1:tsizez+tsizey,tsizez+tsizex+tsizez+1:tsizez+tsizex+tsizez+tsizex,:)=scsimage;
        end;
        
        if (vdata.state.lastcancel==0)
          set(vdata.ui.message,'String',{'Exporting Textured Box Model ...','Loading Texture 3/6 ...'});
          pause(0.1);
          [scsimage,res] = vdata.vast.getscreenshotimage(miplevel,xmin,xmax,ymin,ymin,zsections(1),zsections(end),1);
          scsimage=squeeze(scsimage);
          scsimage=scsimage(:,zsections-zsections(1)+1,:);
          scsimage=permute(scsimage,[2 1 3]);
          scsimage=flipdim(scsimage,1);
          boxtex(1:tsizez,tsizez+1:tsizez+tsizex,:)=scsimage;
        end;
        
        if (vdata.state.lastcancel==0)
          set(vdata.ui.message,'String',{'Exporting Textured Box Model ...','Loading Texture 4/6 ...'});
          pause(0.1);
          [scsimage,res] = vdata.vast.getscreenshotimage(miplevel,xmin,xmin,ymin,ymax,zsections(1),zsections(end),1);
          scsimage=squeeze(scsimage);
          scsimage=scsimage(:,zsections-zsections(1)+1,:);
          scsimage=flipdim(scsimage,2);
          %scsimage=permute(scsimage,[2 1 3]);
          boxtex(tsizez+1:tsizez+tsizey,1:tsizez,:)=scsimage;
        end;
        
        if (vdata.state.lastcancel==0)
          set(vdata.ui.message,'String',{'Exporting Textured Box Model ...','Loading Texture 5/6 ...'});
          pause(0.1);
          [scsimage,res] = vdata.vast.getscreenshotimage(miplevel,xmax,xmax,ymin,ymax,zsections(1),zsections(end),1);
          scsimage=squeeze(scsimage);
          scsimage=scsimage(:,zsections-zsections(1)+1,:);
          %scsimage=flipdim(scsimage,2);
          %scsimage=permute(scsimage,[2 1 3]);
          boxtex(tsizez+1:tsizez+tsizey,tsizez+tsizex+1:tsizez+tsizex+tsizez,:)=scsimage;
        end;
        
        if (vdata.state.lastcancel==0)
          set(vdata.ui.message,'String',{'Exporting Textured Box Model ...','Loading Texture 6/6 ...'});
          pause(0.1);
          [scsimage,res] = vdata.vast.getscreenshotimage(miplevel,xmin,xmax,ymax,ymax,zsections(1),zsections(end),1);
          scsimage=squeeze(scsimage);
          scsimage=scsimage(:,zsections-zsections(1)+1,:);
          scsimage=permute(scsimage,[2 1 3]);
          %scsimage=flipdim(scsimage,1);
          boxtex(tsizez+tsizey+1:tsizez+tsizey+tsizez,tsizez+1:tsizez+tsizex,:)=scsimage;
        end;
        
        if (vdata.state.lastcancel==0)
          % Extend texture edges by 1 pixel to remove texture edge issues
          boxtex(1:tsizez,tsizez,:)=boxtex(1:tsizez,tsizez+1,:);
          boxtex(1:tsizez,tsizez+tsizex+1,:)=boxtex(1:tsizez,tsizez+tsizex,:);
          boxtex(tsizez+tsizey+1:tsizez+tsizey+tsizez,tsizez,:)=boxtex(tsizez+tsizey+1:tsizez+tsizey+tsizez,tsizez+1,:);
          boxtex(tsizez+tsizey+1:tsizez+tsizey+tsizez,tsizez+tsizex+1,:)=boxtex(tsizez+tsizey+1:tsizez+tsizey+tsizez,tsizez+tsizex,:);
          
          boxtex(tsizez,1:tsizez,:)=boxtex(tsizez+1,1:tsizez,:);
          boxtex(tsizez+tsizey+1,1:tsizez,:)=boxtex(tsizez+tsizey,1:tsizez,:);
          boxtex(tsizez,tsizez+tsizex+1:end,:)=boxtex(tsizez+1,tsizez+tsizex+1:end,:);
          boxtex(tsizez+tsizey+1,tsizez+tsizex+1:end,:)=boxtex(tsizez+tsizey,tsizez+tsizex+1:end,:);
          
          texfilename=[objectname '.png'];
          set(vdata.ui.message,'String',{'Exporting Textured Box Model ...',['Saving Texture ' pathname texfilename ' ...']});
          pause(0.1);
          imwrite(boxtex,[pathname texfilename]);
        end;
    end;
    
    if (vdata.state.lastcancel==0)
      if (usetexture==0)
        %%%% Write to file
        fid = fopen(boxfilename,'wt');
        fprintf(fid,'mtllib %s\n',materialfilename);
        fprintf(fid,'usemtl %s\n',materialname);
        
        for i=1:size(vtx,1)
          fprintf(fid,'v %f %f %f\n',vtx(i,2),vtx(i,1),vtx(i,3));
        end;
        fprintf(fid,'g %s\n',objectname);
        
        for i=1:size(quad,1);
          if (flipnormals==0)
            %1 4 3 2 order
            fprintf(fid,'f %d %d %d %d\n',quad(i,1),quad(i,4),quad(i,3),quad(i,2));
          else
            %1 2 3 4 order
            fprintf(fid,'f %d %d %d %d\n',quad(i,1),quad(i,2),quad(i,3),quad(i,4));
          end;
        end
        fprintf(fid,'g\n');
        fclose(fid);
        
        savematerialfile(materialfilenamewithpath, materialname, objectcolor, 0.0);
      else
        % With texture - generate texture coordinates and add reference to texture file
        %%%% Write to file
        fid = fopen(boxfilename,'wt');
        fprintf(fid,'mtllib %s\n',materialfilename);
        fprintf(fid,'usemtl %s\n',materialname);
        
        for i=1:size(vtx,1)
          fprintf(fid,'v %f %f %f\n',vtx(i,2),vtx(i,1),vtx(i,3));
        end;
        for i=1:size(tc,1)
          fprintf(fid,'vt %f %f\n',tc(i,2),tc(i,1));
        end;
        fprintf(fid,'g %s\n',objectname);
        
        for i=1:size(quad,1);
          if (flipnormals==0)
            %1 4 3 2 order
            fprintf(fid,'f %d/%d %d/%d %d/%d %d/%d\n',quad(i,1),quadt(i,1),quad(i,4),quadt(i,4),quad(i,3),quadt(i,3),quad(i,2),quadt(i,2));
          else
            %1 2 3 4 order
            fprintf(fid,'f %d/%d %d/%d %d/%d %d/%d\n',quad(i,1),quadt(i,1),quad(i,2),quadt(i,2),quad(i,3),quadt(i,3),quad(i,4),quadt(i,4));
          end;
        end
        fprintf(fid,'g\n');
        fclose(fid);
        
        savetexturematerialfile(materialfilenamewithpath, materialname, objectcolor, 0.0, texfilename);
      end;
    end;
  end;
  
  if (vdata.state.lastcancel==0)
    set(vdata.ui.message,'String','Done.');
  else
    set(vdata.ui.message,'String','Canceled.');
  end;
  set(vdata.ui.cancelbutton,'Enable','off');
  vdata.state.lastcancel=0;
  releasegui();  
  
  
function [] = callback_box_getvoxelsize(varargin)
  global vdata;
  if (~checkconnection()) return; end;
  
  if (vdata.state.isconnected)
    vinfo=vdata.vast.getinfo();
    vdata.temp.box.voxelsize=[vinfo.voxelsizex vinfo.voxelsizey vinfo.voxelsizez];
    vs=vdata.temp.box.voxelsize;
    set(vdata.temp.box.e3,'String',sprintf('(%.02f, %.02f, %.02f)',vs(1),vs(2),vs(3)));
  else
    warndlg('ERROR: Not connected to VAST. please connect before using this function.','Not connected to VAST');
  end;
  
function [] = callback_box_setcolor(varargin)
  global vdata;
  vdata.data.exportbox.boxcolor=uisetcolor(vdata.data.exportbox.boxcolor);
  set(vdata.temp.e_colorbox,'facecolor',vdata.data.exportbox.boxcolor);
  
function [] = callback_box_setstyle(varargin)
  global vdata;
  style=get(vdata.temp.e_style,'value');
  vdata.data.exportbox.style=style;
  switch style
    case 1 %Wireframe
      set(vdata.temp.e_setcolor,'enable','on');
      set(vdata.temp.e_wireframewidth,'enable','on');
      set(vdata.temp.e_miplevel,'enable','off');
      set(vdata.temp.e_slicestep,'enable','off');
    case 2 %Solid color
      set(vdata.temp.e_setcolor,'enable','on');
      set(vdata.temp.e_wireframewidth,'enable','off');
      set(vdata.temp.e_miplevel,'enable','off');
      set(vdata.temp.e_slicestep,'enable','off');
    case 3 %Textured
      set(vdata.temp.e_setcolor,'enable','off');
      set(vdata.temp.e_wireframewidth,'enable','off');
      set(vdata.temp.e_miplevel,'enable','on');
      set(vdata.temp.e_slicestep,'enable','on');
  end;
  
  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  
  
function [] = callback_exportscalebar(varargin)
  global vdata;
  
  if (~checkconnection()) return; end;
  vinfo=vdata.vast.getinfo();
  if (min([vinfo.datasizex vinfo.datasizey vinfo.datasizez])==0)
    warndlg('ERROR: No volume open in VAST.','VastTools Export 3D Scale Bar as OBJ File');
    return;
  end;
  
  blockgui();
  
  %Display parameter dialog

  if (~isfield(vdata.data,'exportbar'))
    vdata.data.exportbar.xscale=0.001;  %Use these to scale the exported models
    vdata.data.exportbar.yscale=0.001;
    vdata.data.exportbar.zscale=0.001;
    vdata.data.exportbar.xunit=vinfo.voxelsizex;%6*4;  %in nm
    vdata.data.exportbar.yunit=vinfo.voxelsizey; %6*4;  %in nm
    vdata.data.exportbar.zunit=vinfo.voxelsizez; %30; %in nm
    vdata.data.exportbar.offsetx=0; %to translate the exported models in space
    vdata.data.exportbar.offsety=0;
    vdata.data.exportbar.offsetz=0;
    vdata.data.exportbar.orientation=1; %1:+x, 2:+y, 3:+z, 4:-x, 5:-y, 6:-z
    vdata.data.exportbar.length=10000;
    vdata.data.exportbar.width=1000;
    vdata.data.exportbar.invertnormals=0;
    vdata.data.exportbar.invertz=1;
    vdata.data.exportbar.color=[1 1 1];
  end;
  
  scrsz = get(0,'ScreenSize');
  figheight=310;
  f = figure('units','pixels','position',[50 scrsz(4)-100-figheight 420 figheight],'menubar','none','numbertitle','off','name','VastTools - Export 3D Scale Bar as OBJ File','resize','off');
  pos = get(f,'position');
  ax = axes('units','pix','outerposition',[0 0 pos([3 4])],'position',[0 0 pos([3 4])],'parent',f,'visible','off','xlim',[0 pos(3)],'ylim',[0 pos(4)]);
  vpos=figheight-40;

%   uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 150 15],'String','Voxel size (full res)  X:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
%   e8 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%f', vdata.data.exportbar.xunit),'horizontalalignment','left');
%   uicontrol('Style','text', 'Units','Pixels', 'Position',[240 vpos 150 15],'String','Y:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
%   e9 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[260 vpos 50 20],'String',sprintf('%f', vdata.data.exportbar.yunit),'horizontalalignment','left');
%   uicontrol('Style','text', 'Units','Pixels', 'Position',[330 vpos 150 15],'String','Z:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
%   e10 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[350 vpos 50 20],'String',sprintf('%f', vdata.data.exportbar.zunit),'horizontalalignment','left');
%   vpos=vpos-20;
%   t=uicontrol('Style','text', 'Units','Pixels', 'Position',[60 vpos 400 15], 'Tag','t1','String',sprintf('[VAST reports the voxel size to be: (%.2f nm, %.2f nm, %.2f nm)]',vinfo.voxelsizex,vinfo.voxelsizey,vinfo.voxelsizez),'backgroundcolor',get(f,'color'),'horizontalalignment','left');
%   set(t,'tooltipstring','To change, enter the values in VAST under "Info / Volume properties" and save to your EM stack file.');
%   vpos=vpos-30;
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 150 15],'String','Scale models by    X:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e11 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%f',vdata.data.exportbar.xscale),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[240 vpos 150 15],'String','Y:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e12 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[260 vpos 50 20],'String',sprintf('%f',vdata.data.exportbar.yscale),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[330 vpos 150 15],'String','Z:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e13 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[350 vpos 50 20],'String',sprintf('%f',vdata.data.exportbar.zscale),'horizontalalignment','left');
  vpos=vpos-30;
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 150 15],'String','Model output offset   X:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e14 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%f',vdata.data.exportbar.offsetx),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[240 vpos 150 15],'String','Y:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e15 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[260 vpos 50 20],'String',sprintf('%f',vdata.data.exportbar.offsety),'horizontalalignment','left');
  uicontrol('Style','text', 'Units','Pixels', 'Position',[330 vpos 150 15],'String','Z:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e16 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[350 vpos 50 20],'String',sprintf('%f',vdata.data.exportbar.offsetz),'horizontalalignment','left');
  vpos=vpos-40;
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 150 15],'String','Scale Bar length (nm):','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_length = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 100 20],'String',sprintf('%f',vdata.data.exportbar.length),'horizontalalignment','left');
  vpos=vpos-30;
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 150 15],'String','Scale Bar width (nm):','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_width = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 100 20],'String',sprintf('%f',vdata.data.exportbar.width),'horizontalalignment','left');
  vpos=vpos-40;
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 140 15], 'String','Scale Bar Orientation:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  str=cell(6,1);
  str{1}='+ X';
  str{2}='+ Y';
  str{3}='+ Z';
  str{4}='- X';
  str{5}='- Y';
  str{6}='- Z';
  vdata.temp.e_orientation = uicontrol('Style','popupmenu','String',str,'Value',vdata.data.exportbar.orientation,'Position',[170 vpos 100 20],'CallBack',{@callback_bar_setorientation});
  vpos=vpos-30;
 
  uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 90 15],'String','Scale Bar Color:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_colorbox = patch('xdata',[170 189 189 170],'ydata',[vpos+1 vpos+1 vpos+20 vpos+20],'facecolor',vdata.data.exportbar.color,'parent',ax);
  vdata.temp.e_setcolor = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[200 vpos 30 20], 'String','Set', 'CallBack',{@callback_bar_setcolor,1});
  vpos=vpos-40;
  
  c1 = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[30 vpos 130 15],'Value',vdata.data.exportbar.invertnormals,'string','Invert Normals','backgroundcolor',get(f,'color'));
  c2 = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[170 vpos 130 15],'Value',vdata.data.exportbar.invertz,'string','Invert Z axis','backgroundcolor',get(f,'color')); 
  
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[110 20 60 20], 'String','OK', 'CallBack',{@callback_done});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[250 20 60 20], 'String','Cancel', 'CallBack',{@callback_canceled});

  vdata.state.lastcancel=1;
  vdata.ui.temp.closefig=0;
  %callback_box_setstyle();
  uiwait(f);
  
  if (vdata.state.lastcancel==0)

%     vdata.data.exportbar.xunit = str2num(get(e8,'String'));
%     vdata.data.exportbar.yunit = str2num(get(e9,'String'));
%     vdata.data.exportbar.zunit = str2num(get(e10,'String'));
    vdata.data.exportbar.xscale = str2num(get(e11,'String'));
    vdata.data.exportbar.yscale = str2num(get(e12,'String'));
    vdata.data.exportbar.zscale = str2num(get(e13,'String'));
    vdata.data.exportbar.offsetx = str2num(get(e14,'String'));
    vdata.data.exportbar.offsety = str2num(get(e15,'String'));
    vdata.data.exportbar.offsetz = str2num(get(e16,'String'));

    vdata.data.exportbar.length = str2num(get(vdata.temp.e_length,'String')); 
    vdata.data.exportbar.width = str2num(get(vdata.temp.e_width,'String')); 
    
    vdata.data.exportbar.orientation=get(vdata.temp.e_orientation,'value');
    vdata.data.exportbar.invertnormals = get(c1,'value');
    vdata.data.exportbar.invertz = get(c2,'value');
  end;
  
  if (vdata.ui.temp.closefig==1) %to distinguish close on button press and close on window x
    close(f);
  end;

  if (vdata.state.lastcancel==0)
    if ((vdata.data.exportbar.xunit==0)||(vdata.data.exportbar.yunit==0)||(vdata.data.exportbar.zunit==0))
      res = questdlg(sprintf('Warning: The voxel size is set to (%f,%f,%f) which will result in a zero-sized model. Are you sure you want to continue?',vdata.data.exportbar.xunit,vdata.data.exportbar.yunit,vdata.data.exportbar.zunit),'Export 3D Scale Bar as OBJ File','Yes','No','Yes');
      if strcmp(res,'No')
        releasegui();
        return; 
      end
    end;
    
    %get filename to save box
    targetfilename=sprintf('scalebar_%d_nm.obj',vdata.data.exportbar.length);
    [filename, pathname] = uiputfile({'*.obj';'*.*'},'Export 3D Scale Bar as OBJ File - Select target file name',targetfilename);
    if (filename==0)
      %'Cancel' was pressed. Don't save.
      releasegui();
      return;
    end;

    length=vdata.data.exportbar.length;
    width=vdata.data.exportbar.width;
    xscale=vdata.data.exportbar.xscale;
    yscale=vdata.data.exportbar.yscale;
    zscale=vdata.data.exportbar.zscale;
    offsetx=vdata.data.exportbar.offsetx;
    offsety=vdata.data.exportbar.offsety;
    offsetz=vdata.data.exportbar.offsetz;
    
    xmin=0; ymin=0; zmin=0;
    switch vdata.data.exportbar.orientation
      case 1 % +X
        xmax=xmin+length*xscale;
        ymax=ymin+width*yscale;
        zmax=zmin+width*zscale;
      case 2 % +Y
        xmax=xmin+width*xscale;
        ymax=ymin+length*yscale;
        zmax=zmin+width*zscale;
      case 3 % +Z
        xmax=xmin+width*xscale;
        ymax=ymin+width*yscale;
        zmax=zmin+length*zscale;
      case 4 % -X
        xmin=xmin-length*xscale;
        xmax=xmin+length*xscale;
        ymax=ymin+width*yscale;
        zmax=zmin+width*zscale;
      case 5 % -Y
        xmax=xmin+width*xscale;
        ymin=ymin-length*yscale;
        ymax=ymin+length*yscale;
        zmax=zmin+width*zscale;
      case 6 % -Z
        xmax=xmin+width*xscale;
        ymax=ymin+width*yscale;
        zmin=zmin-length*zscale;
        zmax=zmin+length*zscale;
    end;
    %cornercoords=[vdata.data.region.xmin vdata.data.region.ymin vdata.data.region.zmin vdata.data.region.xmax vdata.data.region.ymax vdata.data.region.zmax];
    cornercoords=[xmin+offsetx ymin+offsety zmin+offsetz xmax+offsetx ymax+offsety zmax+offsetz];

    %voxelsize=[vdata.data.exportbar.xunit vdata.data.exportbar.yunit vdata.data.exportbar.zunit];
    barfilename=[pathname filename];
    objectname=filename(1:end-4);
    materialname=[objectname '_mtl'];
    materialfilenamewithpath=[barfilename(1:end-4) '.mtl'];
    materialfilename=[materialname(1:end-4) '.mtl'];
    objectcolor=vdata.data.exportbar.color;
    flipnormals=vdata.data.exportbar.invertnormals;
    invert_z=vdata.data.exportbar.invertz;
    
    vtx=zeros(8,3);
    v=1;
    for z=0:1
      for y=0:1
        for x=0:1
          vtx(v,1)=cornercoords(x*3+1);
          vtx(v,2)=cornercoords(y*3+2);
          vtx(v,3)=cornercoords(z*3+3);
          if (invert_z==1)
            vtx(v,3)=-vtx(v,3);
          end;
          v=v+1;
        end;
      end;
    end;
    
    quad=[[1 2 4 3]; [3 4 8 7]; [4 2 6 8]; [2 1 5 6]; [1 3 7 5]; [7 8 6 5]]; %clockwise
    
    %%%% Write to file
    fid = fopen(barfilename,'wt');
    fprintf(fid,'mtllib %s\n',materialfilename);
    fprintf(fid,'usemtl %s\n',materialname);
    
    for i=1:size(vtx,1)
      fprintf(fid,'v %f %f %f\n',vtx(i,2),vtx(i,1),vtx(i,3));
    end;
    fprintf(fid,'g %s\n',objectname);
    
    for i=1:size(quad,1);
      if (flipnormals==0)
        %1 4 3 2 order
        fprintf(fid,'f %d %d %d %d\n',quad(i,1),quad(i,4),quad(i,3),quad(i,2));
      else
        %1 2 3 4 order
        fprintf(fid,'f %d %d %d %d\n',quad(i,1),quad(i,2),quad(i,3),quad(i,4));
      end;
    end
    fprintf(fid,'g\n');
    fclose(fid);
    
    savematerialfile(materialfilenamewithpath, materialname, objectcolor, 0.0);
  end;
  
  releasegui();
  
  
function [] = callback_bar_setcolor(varargin)
  global vdata;
  vdata.data.exportbar.color=uisetcolor(vdata.data.exportbar.color);
  set(vdata.temp.e_colorbox,'facecolor',vdata.data.exportbar.color);

  
function [] = callback_bar_setorientation(varargin)
  global vdata;
  ori=get(vdata.temp.e_orientation,'value');
  vdata.data.exportbar.orientation=ori;

  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Simple Projection Exporting Functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [] = callback_exportprojection(varargin)
  global vdata;
  
  if (~checkconnection()) return; end;
  
  vinfo=vdata.vast.getinfo();
  if (min([vinfo.datasizex vinfo.datasizey vinfo.datasizez])==0)
    warndlg('ERROR: No volume open in VAST.','VastTools projection image exporting');
    return;
  end;
  
%  blockgui();
  
  %Display parameter dialog
  if (~isfield(vdata.data,'region'))
    vdata.data.region.xmin=0;
    vdata.data.region.xmax=vinfo.datasizex-1;
    vdata.data.region.ymin=0;
    vdata.data.region.ymax=vinfo.datasizey-1;
    vdata.data.region.zmin=0; %first slice
    vdata.data.region.zmax=vinfo.datasizez-1; %last slice
  else
    if (vdata.data.region.xmin<0) vdata.data.region.xmin=0; end;
    if (vdata.data.region.xmax>(vinfo.datasizex-1)) vdata.data.region.xmax=vinfo.datasizex-1; end;
    if (vdata.data.region.ymin<0) vdata.data.region.ymin=0; end;
    if (vdata.data.region.ymax>(vinfo.datasizey-1)) vdata.data.region.ymax=vinfo.datasizey-1; end;
    if (vdata.data.region.zmin<0) vdata.data.region.zmin=0; end; %first slice
    if (vdata.data.region.zmax>(vinfo.datasizez-1)) vdata.data.region.zmax=vinfo.datasizez-1; end;
  end;
  if (~isfield(vdata.data,'exportproj'))
    vdata.data.exportproj.miplevel=0;
    vdata.data.exportproj.slicestep=1;
    
    vdata.data.exportproj.overlap=0;
    vdata.data.exportproj.projaxis=5; %1:+X, 2:-X, 3:+Y, 4:-Y, 5:+Z, 6:-Z
    vdata.data.exportproj.stretchz=2;

    vdata.data.exportproj.savetofile=1;
    vdata.data.exportproj.showinwindow=1;
    vdata.data.exportproj.targetfilename='projection.png';
    vdata.data.exportproj.targetfoldername=pwd;
    
    vdata.data.exportproj.segpreprocess=2; %extractwhich
    vdata.data.exportproj.expandsegmentation=0; %number of pixels to expand segmentation map (negative values shrink)
    vdata.data.exportproj.blurdistance=0; %in pixels; blurs inward
    vdata.data.exportproj.imagesource=1; %1: Segmentation (all layers); 2: Segmentation (sel. layer); 3: Screenshots
    vdata.data.exportproj.opacitysource=1; %1: Segmented, 2: Unsegmented, 3: All
    vdata.data.exportproj.blendmode=1; %1:Alpha-blend, 2: Additive, 3: Maximum projection
    vdata.data.exportproj.objectopacity=1; %opacity strength 0..1
    vdata.data.exportproj.useshadows=0;
    vdata.data.exportproj.shadowcone=2;
    vdata.data.exportproj.depthattenuation=1;
    vdata.data.exportproj.bgcolor=[0 0 0];

    vdata.data.exportproj.finalnormalize=1;
  else
    if (vdata.data.exportproj.miplevel>(vinfo.nrofmiplevels-1)) vdata.data.exportproj.miplevel=vinfo.nrofmiplevels-1; end;
  end;
  
  nrofsegments=vdata.vast.getnumberofsegments();
  if (nrofsegments==0)
    vdata.data.exportproj.rendermode=2;
  end;
  
  scrsz = get(0,'ScreenSize');
  figheight=650;
  f = figure('units','pixels','position',[50 scrsz(4)-100-figheight 500 figheight],'menubar','none','numbertitle','off','name','VastTools - Export Projection Image','resize','off');
  pos = get(f,'position');
  ax = axes('units','pix','outerposition',[0 0 pos([3 4])],'position',[0 0 pos([3 4])],'parent',f,'visible','off','xlim',[0 pos(3)],'ylim',[0 pos(4)]);
  vpos=figheight-40;
 
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 120 15], 'Tag','t1','String','Render at resolution:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  str=cell(vinfo.nrofmiplevels,1);
  vx=vinfo.voxelsizex;
  vy=vinfo.voxelsizey;
  vz=vinfo.voxelsizez;
  for i=1:1:vinfo.nrofmiplevels
    str{i}=sprintf('Mip %d - (%.2f nm, %.2f nm, %.2f nm) voxels',i-1,vx,vy,vz);
    vx=vx*2; vy=vy*2;
  end;
  vdata.temp.pmh = uicontrol('Style','popupmenu','String',str,'Value',vdata.data.exportproj.miplevel+1,'Position',[170 vpos 310 20],'Callback',{@callback_update_targetimagesize});
  vpos=vpos-30;

  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 150 15],'String','Use every nth slice:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_slicestep = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%d',vdata.data.exportproj.slicestep),'horizontalalignment','left');
  vpos=vpos-40;
  
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 120 15],'String','Render from area:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[340 vpos+10 140 20], 'String','Set to full', 'CallBack',{@callback_region_settofull,1});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[340 vpos-15 140 20], 'String','Set to selected bbox', 'CallBack',{@callback_region_settobbox,1});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[340 vpos-40 140 20], 'String','Set to current voxel', 'CallBack',{@callback_region_settocurrentvoxel,1});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[340 vpos-65 140 20], 'String','Extend to current voxel', 'CallBack',{@callback_region_extendtocurrentvoxel,1});
  
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[130 vpos 100 15],'String','X min:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_xmin = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%d', vdata.data.region.xmin),'horizontalalignment','left','Callback',{@callback_update_targetimagesize});
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[230 vpos 100 15],'String','X max:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_xmax = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[270 vpos 50 20],'String',sprintf('%d',vdata.data.region.xmax),'horizontalalignment','left','Callback',{@callback_update_targetimagesize});
  vpos=vpos-30;
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[130 vpos 100 15],'String','Y min:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_ymin = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%d',vdata.data.region.ymin),'horizontalalignment','left','Callback',{@callback_update_targetimagesize});
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[230 vpos 100 15],'String','Y max:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_ymax = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[270 vpos 50 20],'String',sprintf('%d',vdata.data.region.ymax),'horizontalalignment','left','Callback',{@callback_update_targetimagesize});
  vpos=vpos-30;
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[130 vpos 100 15],'String','Z min:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_zmin = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%d',vdata.data.region.zmin),'horizontalalignment','left','Callback',{@callback_update_targetimagesize});
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[230 vpos 100 15],'String','Z max:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_zmax = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[270 vpos 50 20],'String',sprintf('%d',vdata.data.region.zmax),'horizontalalignment','left','Callback',{@callback_update_targetimagesize});
  vpos=vpos-40;
  
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 120 15], 'Tag','t1','String','Projection axis:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  str={'+X (lowest X in front)','-X (highest X in front)','+Y (lowest Y in front)','-Y (highest Y in front)','+Z (lowest Z in front)','-Z (highest Z in front)'};
  vdata.temp.pmaxis = uicontrol('Style','popupmenu','String',str,'Value',vdata.data.exportproj.projaxis,'Position',[170 vpos 150 20],'Callback',{@callback_update_targetimagesize});
  str={'No stretching','Stretch Z (nearest)','Stretch Z (interpolated)'};
  vdata.temp.pmstretch = uicontrol('Style','popupmenu','String',str,'Value',vdata.data.exportproj.stretchz,'Position',[330 vpos 150 20]);
  vpos=vpos-30;

  vdata.temp.t_targetsize= uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 450 16],'backgroundcolor',[0.75 0.75 0.65],'horizontalalignment','left');
  callback_update_targetimagesize();
  vpos=vpos-30;
  
  c1 = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[30 vpos 150 15],'Value',vdata.data.exportproj.savetofile,'string','Save to file','backgroundcolor',get(f,'color')); 
  c2 = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[170 vpos 200 15],'Value',vdata.data.exportproj.showinwindow,'string','Show render progress','backgroundcolor',get(f,'color')); 

  vpos=vpos-30;
    
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 100 15],'String','File name:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  e20 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[120 vpos 290 20],'String',vdata.data.exportproj.targetfilename,'horizontalalignment','left');
  vpos=vpos-30;
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 100 15],'String','Target folder:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e21 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[120 vpos 290 20],'String',vdata.data.exportproj.targetfoldername,'horizontalalignment','left');
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[420 vpos 60 20], 'String','Browse...', 'CallBack',{@callback_exportproj_browse});
  vpos=vpos-40;

  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 160 15], 'Tag','t1','String','Segmentation preprocessing:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  str=cell(4,1);
  str{1}='All segments individually, uncollapsed';
  str{2}='All segments, collapsed as in VAST';
  str{3}='Selected segment and children, uncollapsed';
  str{4}='Selected segment and children, collapsed as in VAST';
  pmh2 = uicontrol('Style','popupmenu','String',str,'Value',vdata.data.exportproj.segpreprocess,'Position',[190 vpos 290 20]);
  vpos=vpos-30;
  
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 150 15],'String','Expand segments by n pixels:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_expandseg = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[190 vpos 60 20],'String',sprintf('%d', vdata.data.exportproj.expandsegmentation),'horizontalalignment','left');

  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[290 vpos 120 15],'String','Blur edges by n pixels:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_blurdist = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[420 vpos 60 20],'String',sprintf('%d', vdata.data.exportproj.blurdistance),'horizontalalignment','left');
  vpos=vpos-40;
  
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 100 15],'String','Image source:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  str=cell(3,1);
  str{1}='Segmentation (all layers)';
  str{2}='Segmentation (sel. layer)';
  str{3}='Screenshots';

  pmh3 = uicontrol('Style','popupmenu','String',str,'Value',vdata.data.exportproj.imagesource,'Position',[120 vpos 170 20]);
  
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[310 vpos 110 15],'String','Background Color:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_colorbox=patch('xdata',[420 439 439 420],'ydata',[vpos+1 vpos+1 vpos+20 vpos+20],'facecolor',vdata.data.exportproj.bgcolor,'parent',ax);
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[450 vpos 30 20], 'String','Set', 'CallBack',{@callback_setbgcolor,1});
  vpos=vpos-30;
  
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 100 15],'String','Opacity source:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  str=cell(7,1);
  str{1}='Segmented areas (all layers)';
  str{2}='Segmented areas (sel. layer)';
  str{3}='Unsegmented areas (all layers)';
  str{4}='Unsegmented areas (sel. layer)';
  str{5}='Screenshots, show bright';
  str{6}='Screenshots, show dark';
  str{7}='Constant';
  pmh4 = uicontrol('Style','popupmenu','String',str,'Value',vdata.data.exportproj.opacitysource,'Position',[120 vpos 170 20]);

  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[310 vpos 120 15],'String','Object opacity [0..1]:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_objectopacity = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[420 vpos 60 20],'String',sprintf('%f', vdata.data.exportproj.objectopacity),'horizontalalignment','left');
  vpos=vpos-30;
  
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 100 15],'String','Blending mode:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  str=cell(4,1);
  str{1}='Alpha blending';
  str{2}='Additive';
  str{3}='Max projection';
  str{4}='Min projection';
  pmh5 = uicontrol('Style','popupmenu','String',str,'Value',vdata.data.exportproj.blendmode,'Position',[120 vpos 170 20]);
  vpos=vpos-30;

  c3 = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[30 vpos 100 15],'Value',vdata.data.exportproj.useshadows,'string','Use shadows','backgroundcolor',get(f,'color')); 
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[150 vpos-1 160 15],'String','Shadow cone angle (pix/slice):','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_shadowcone = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[310 vpos-2 100 20],'String',sprintf('%f', vdata.data.exportproj.shadowcone),'horizontalalignment','left');
  vpos=vpos-30;
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 200 15],'String','Depth attenuation (far brightness) [0..1]:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_depthattenuation = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[240 vpos 60 20],'String',sprintf('%f', vdata.data.exportproj.depthattenuation),'horizontalalignment','left');
  vpos=vpos-30;
  c4 = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[30 vpos 250 15],'Value',vdata.data.exportproj.finalnormalize,'string','Normalize projection image','backgroundcolor',get(f,'color')); 
  vpos=vpos-30;
  
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[150 20 60 20], 'String','OK', 'CallBack',{@callback_done});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[290 20 60 20], 'String','Cancel', 'CallBack',{@callback_canceled});

  vdata.state.lastcancel=1;
  vdata.ui.temp.closefig=0;
  uiwait(f);
  
  if (vdata.state.lastcancel==0)
    vdata.data.exportproj.miplevel=get(vdata.temp.pmh,'value')-1;
    
    vdata.data.region.xmin = str2num(get(vdata.temp.e_xmin,'String'));
    vdata.data.region.xmax = str2num(get(vdata.temp.e_xmax,'String'));
    vdata.data.region.ymin = str2num(get(vdata.temp.e_ymin,'String'));
    vdata.data.region.ymax = str2num(get(vdata.temp.e_ymax,'String'));
    vdata.data.region.zmin = str2num(get(vdata.temp.e_zmin,'String'));
    vdata.data.region.zmax = str2num(get(vdata.temp.e_zmax,'String'));
    
    vdata.data.exportproj.slicestep = str2num(get(vdata.temp.e_slicestep,'String'));
    vdata.data.exportproj.projaxis = get(vdata.temp.pmaxis,'value');
    vdata.data.exportproj.stretchz = get(vdata.temp.pmstretch,'value');
    vdata.data.exportproj.savetofile = get(c1,'value');
    vdata.data.exportproj.showinwindow = get(c2,'value');
    vdata.data.exportproj.targetfilename=get(e20,'String');
    vdata.data.exportproj.targetfoldername=get(vdata.temp.e21,'String');

    vdata.data.exportproj.segpreprocess=get(pmh2,'value');
    vdata.data.exportproj.expandsegmentation = str2num(get(vdata.temp.e_expandseg,'String'));
    vdata.data.exportproj.blurdistance = str2num(get(vdata.temp.e_blurdist,'String'));
    vdata.data.exportproj.imagesource=get(pmh3,'value');
    vdata.data.exportproj.opacitysource=get(pmh4,'value');
    vdata.data.exportproj.blendmode=get(pmh5,'value');
    vdata.data.exportproj.objectopacity = str2num(get(vdata.temp.e_objectopacity,'String'));
    
    vdata.data.exportproj.useshadows = get(c3,'value');
    vdata.data.exportproj.shadowcone = str2num(get(vdata.temp.e_shadowcone,'String'));
   
    vdata.data.exportproj.depthattenuation = str2num(get(vdata.temp.e_depthattenuation,'String'));
    if (vdata.data.exportproj.depthattenuation<0) vdata.data.exportproj.depthattenuation=0; end;
    if (vdata.data.exportproj.depthattenuation>1) vdata.data.exportproj.depthattenuation=1; end;
    vdata.data.exportproj.finalnormalize = get(c4,'value');
  end;
  
  if (vdata.ui.temp.closefig==1) %to distinguish close on button press and close on window x
    close(f);
  end;

  if (vdata.state.lastcancel==0)

    if ((nrofsegments==0) && ((vdata.data.exportproj.imagesource==1)||(vdata.data.exportproj.imagesource==2)||(vdata.data.exportproj.opacitysource<5)))
      warndlg('ERROR: No segmentation available in VAST. Cannot use segmentation during exporting!','VastTools projection image exporting');
      releasegui();
      setcanceledmsg();
      return;
    end;
    
    %reevaluate target image size
    xmin=bitshift(vdata.data.region.xmin,-vdata.data.exportproj.miplevel);
    xmax=bitshift(vdata.data.region.xmax,-vdata.data.exportproj.miplevel);
    ymin=bitshift(vdata.data.region.ymin,-vdata.data.exportproj.miplevel);
    ymax=bitshift(vdata.data.region.ymax,-vdata.data.exportproj.miplevel);
    zval=vdata.data.region.zmin:vdata.data.exportproj.slicestep:vdata.data.region.zmax;
    switch vdata.data.exportproj.projaxis
      case {1,2} %X
        timagewidth=(ymax-ymin+1);
        timageheight=max(size(zval));
      case {3,4} %Y
        timagewidth=(xmax-xmin+1);
        timageheight=max(size(zval));
      case {5,6} %Z
        timagewidth=(xmax-xmin+1);
        timageheight=(ymax-ymin+1);
    end;
    
    if ((timagewidth>2000)||(timageheight>2000))
      res = questdlg(sprintf('With these settings you will render an image which is %d by %d pixels large. Are you sure?',timagewidth, timageheight),'VastTools projection image exporting','Yes','No','Yes');
      if strcmp(res,'No')
        releasegui();
        setcanceledmsg();
        return; 
      end;
    end;

    renderprojection();
  end;  
  releasegui();  

  
function [] = callback_update_targetimagesize(varargin)
  global vdata;
  
  vdata.data.exportproj.miplevel=get(vdata.temp.pmh,'value')-1;
  vdata.data.region.xmin = str2num(get(vdata.temp.e_xmin,'String'));
  vdata.data.region.xmax = str2num(get(vdata.temp.e_xmax,'String'));
  vdata.data.region.ymin = str2num(get(vdata.temp.e_ymin,'String'));
  vdata.data.region.ymax = str2num(get(vdata.temp.e_ymax,'String'));
  vdata.data.region.zmin = str2num(get(vdata.temp.e_zmin,'String'));
  vdata.data.region.zmax = str2num(get(vdata.temp.e_zmax,'String'));
  vdata.data.exportproj.slicestep = str2num(get(vdata.temp.e_slicestep,'String'));
  vdata.data.exportproj.projaxis = get(vdata.temp.pmaxis,'value');
  
  xmin=bitshift(vdata.data.region.xmin,-vdata.data.exportproj.miplevel);
  xmax=bitshift(vdata.data.region.xmax,-vdata.data.exportproj.miplevel);
  ymin=bitshift(vdata.data.region.ymin,-vdata.data.exportproj.miplevel);
  ymax=bitshift(vdata.data.region.ymax,-vdata.data.exportproj.miplevel);
  zval=vdata.data.region.zmin:vdata.data.exportproj.slicestep:vdata.data.region.zmax;
  switch vdata.data.exportproj.projaxis
    case {1,2} %X
      timagewidth=(ymax-ymin+1);
      timageheight=max(size(zval));
    case {3,4} %Y
      timagewidth=(xmax-xmin+1);
      timageheight=max(size(zval));
    case {5,6} %Z
      timagewidth=(xmax-xmin+1);
      timageheight=(ymax-ymin+1);
  end;

  set(vdata.temp.t_targetsize,'String',sprintf('Target image size with these settings: (%d, %d)',timagewidth,timageheight));


function [] = callback_exportproj_browse(varargin)
  global vdata;
  foldername = uigetdir(vdata.data.exportproj.targetfoldername,'VastTools - Select target folder for projection image:');
  if (foldername~=0)
    set(vdata.temp.e21,'String',foldername);
    vdata.data.exportproj.targetfoldername=foldername;
  end;
  
function [] = callback_setbgcolor(varargin)
global vdata;
vdata.data.exportproj.bgcolor=uisetcolor(vdata.data.exportproj.bgcolor);
set(vdata.temp.e_colorbox,'facecolor',vdata.data.exportproj.bgcolor);
  
function [] = renderprojection()
  global vdata;
  
  if (~checkconnection()) return; end;
  
  set(vdata.ui.cancelbutton,'Enable','on');
  set(vdata.ui.message,'String',{'Generating Projection Image ...','Loading metadata ...'});
  pause(0.1);
  
  %releasegui();
  
  param=vdata.data.exportproj;
  rparam=vdata.data.region;
  vinfo=vdata.vast.getinfo();
  
  xmin=bitshift(rparam.xmin,-param.miplevel);
  xmax=bitshift(rparam.xmax+1,-param.miplevel)-1;
  ymin=bitshift(rparam.ymin,-param.miplevel);
  ymax=bitshift(rparam.ymax+1,-param.miplevel)-1;
  zmin=rparam.zmin;
  zmax=rparam.zmax;
  
  mipfact=bitshift(1,param.miplevel);
  
  slicestep=vdata.data.exportproj.slicestep;
  
  segpreprocess=vdata.data.exportproj.segpreprocess; %extractwhich
  collapsesegments=0; if ((segpreprocess==2)||(segpreprocess==4)) collapsesegments=1; end;
  expandsegmentation=vdata.data.exportproj.expandsegmentation; %number of pixels to expand segmentation map (negative values shrink)
  blurdistance=vdata.data.exportproj.blurdistance; %in pixels; blurs inward
  imagesource=vdata.data.exportproj.imagesource; %1: Segmentation (sel. layer); 2: Segmentation (all layers), 3: Selected EM layer; 4: Screenshots; 5: Segment Volume Colors (prev: 1: seg, 2: Selected EM layer; 3: Screenshots; 4: segvolcolors
  opacitysource=vdata.data.exportproj.opacitysource; %1: Segmented, 2: Unsegmented, 3: All
  blendmode=vdata.data.exportproj.blendmode; %1:Alpha-blend, 2: Additive, 3: Maximum projection
  objectopacity=vdata.data.exportproj.objectopacity; %opacity strength 0..1
  useshadows=vdata.data.exportproj.useshadows;
  shadowcone=vdata.data.exportproj.shadowcone;
  depthattenuation=vdata.data.exportproj.depthattenuation;
  finalnormalize=vdata.data.exportproj.finalnormalize;
  bgcolor=vdata.data.exportproj.bgcolor;
  
  if (vdata.data.exportproj.showinwindow==1)
    lfig=figure; lax=axes; title(lax,'Projection Image');
  end;
 
  if ((opacitysource<5)||(imagesource<3))
    %find the layer numbers of all segmentation layers
    [nroflayers, res] = vdata.vast.getnroflayers();
    seglayernrs=[];
    for layernr=0:nroflayers-1
      [linfo, res] = vdata.vast.getlayerinfo(layernr);
      if (linfo.type==1) %this is a segmentation layer
        seglayernrs=[seglayernrs layernr];
      end;
    end;
    
    [selectedlayernr, selectedemlayernr, selectedsegmentlayernr, res]=vdata.vast.getselectedlayernr();
    
    %define segment translation for all segmentation layers
    sltranspre=cell(nroflayers,1);
    sltranspost=cell(nroflayers,1);
    slcols=cell(nroflayers,1);
    for slnn=1:length(seglayernrs);
      sln=seglayernrs(slnn);
      %set segmentation layer
      res=vdata.vast.setselectedlayernr(sln);
      [ldata,res] = vdata.vast.getallsegmentdatamatrix();
      slcols{sln}=ldata(:,3:5);
      switch segpreprocess
        case 1  %All segments individually, uncollapsed
          sltranspre{sln}=[];
          sltranspost{sln}=[];
          
        case 2  %All segments, collapsed as in Vast
          %4: Collapse segments as in the view during segment text file exporting
          sltranspre{sln}=ldata(:,1);
          sltranspost{sln}=ldata(:,18);
          
        case 3  %Selected segment and children, uncollapsed
          selected=find(bitand(ldata(:,2),65536)>0);
          if (min(size(selected))~=0)
            selected=[selected getchildtreeids(ldata,selected)];
          end;
          sltranspre{sln}=ldata(selected,1);
          sltranspost{sln}=ldata(selected,1);
          
        case 4  %Selected segment and children, collapsed as in Vast
          selected=find(bitand(ldata(:,2),65536)>0);
          if (min(size(selected))==0)
            %None selected: choose all, collapsed
            selected=ldata(:,1);
          else
            selected=[selected getchildtreeids(ldata,selected)];
          end;
          sltranspre{sln}=ldata(selected,1);
          sltranspost{sln}=ldata(selected,18);
      end;
    end;
  end;
 
  %%%%%%%%%%%%%%%%%
  %Set up mapping between source and target volumes based on projection axis
  
  slabthickness=16;
  
  swidth=xmax-xmin+1;
  sheight=ymax-ymin+1;
  sdepth=zmax-zmin+1;
  
  switch vdata.data.exportproj.projaxis
    case 1 %'+X (lowest X in front)'
      twidth=ymax-ymin+1;
      theight=zmax-zmin+1;
      tdepth=xmax-xmin+1;
      twmin=ymin;
      thmin=zmin;
      tdmin=xmin;
      tdir=1;

      projectback=[[0 0 mipfact xmin*mipfact]; [mipfact 0 0 ymin*mipfact]; [0 slicestep 0 zmin]];
      if (slicestep==1) %load in slabs
        nrofslabs=ceil(tdepth/slabthickness);
        sslabboxes=zeros(nrofslabs,6);
        slabstart=tdmin:slabthickness:tdmin+tdepth-1;
        for i=1:1:nrofslabs
          sslabbbox(i,:)=[slabstart(i) min([slabstart(i)+slabthickness-1 tdmin+tdepth-1]) ymin ymax zmin zmax];
        end;
      else
        slabc=tdmin:slicestep:tdmin+tdepth-1;
        nrofslabs=size(slabc,2);
        sslabbox=zeros(nrofslabs,6);
        for i=1:1:nrofslabs
          sslabbbox(i,:)=[slabc(i) slabc(i) ymin ymax zmin zmax];
        end;
      end;
    case 2 %'-X (highest X in front)'
      twidth=ymax-ymin+1;
      theight=zmax-zmin+1;
      tdepth=xmax-xmin+1;
      twmin=ymin;
      thmin=zmin;
      tdmin=xmin;
      tdir=-1;

      projectback=[[0 0 -mipfact xmax*mipfact]; [-mipfact 0 0 ymax*mipfact]; [0 slicestep 0 zmin]];
      if (slicestep==1) %load in slabs
        nrofslabs=ceil(tdepth/slabthickness);
        sslabbox=zeros(nrofslabs,6);
        slabstart=tdmin:slabthickness:tdmin+tdepth-1;
        slabstart=fliplr(slabstart);
        for i=1:1:nrofslabs
          sslabbbox(i,:)=[slabstart(i) min([slabstart(i)+slabthickness-1 tdmin+tdepth-1]) ymin ymax zmin zmax];
        end;
      else
        slabc=tdmin:slicestep:tdmin+tdepth-1;
        slabc=fliplr(slabc);
        nrofslabs=size(slabc,2);
        sslabbox=zeros(nrofslabs,6);
        for i=1:1:nrofslabs
          sslabbbox(i,:)=[slabc(i) slabc(i) ymin ymax zmin zmax];
        end;
      end;
    case 3 %'+Y (lowest Y in front)'
      twidth=xmax-xmin+1;
      theight=zmax-zmin+1;
      tdepth=ymax-ymin+1;
      twmin=xmin;
      thmin=zmin;
      tdmin=ymin;
      tdir=1;
      projectback=[[-mipfact 0 0 xmax*mipfact]; [0 0 mipfact ymin*mipfact]; [0 slicestep 0 zmin]];
      if (slicestep==1) %load in slabs
        nrofslabs=ceil(tdepth/slabthickness);
        sslabbox=zeros(nrofslabs,6);
        slabstart=tdmin:slabthickness:tdmin+tdepth-1;
        for i=1:1:nrofslabs
          sslabbbox(i,:)=[xmin xmax slabstart(i) min([slabstart(i)+slabthickness-1 tdmin+tdepth-1]) zmin zmax];
        end;
      else
        slabc=tdmin:slicestep:tdmin+tdepth-1;
        nrofslabs=size(slabc,2);
        sslabbox=zeros(nrofslabs,6);
        for i=1:1:nrofslabs
          sslabbbox(i,:)=[xmin xmax slabc(i) slabc(i) zmin zmax];
        end;
      end;
    case 4 %'-Y (highest Y in front)'
      twidth=xmax-xmin+1;
      theight=zmax-zmin+1;
      tdepth=ymax-ymin+1;
      twmin=xmin;
      thmin=zmin;
      tdmin=ymin;
      tdir=-1;
      projectback=[[mipfact 0 0 xmin*mipfact]; [0 0 -mipfact ymax*mipfact]; [0 slicestep 0 zmin]];
      if (slicestep==1) %load in slabs
        nrofslabs=ceil(tdepth/slabthickness);
        sslabbox=zeros(nrofslabs,6);
        slabstart=tdmin:slabthickness:tdmin+tdepth-1;
        slabstart=fliplr(slabstart);
        for i=1:1:nrofslabs
          sslabbbox(i,:)=[xmin xmax slabstart(i) min([slabstart(i)+slabthickness-1 tdmin+tdepth-1]) zmin zmax];
        end;
      else
        slabc=tdmin:slicestep:tdmin+tdepth-1;
        slabc=fliplr(slabc);
        nrofslabs=size(slabc,2);
        sslabbox=zeros(nrofslabs,6);
        for i=1:1:nrofslabs
          sslabbbox(i,:)=[xmin xmax slabc(i) slabc(i) zmin zmax];
        end;
      end;
    case 5 %'+Z (lowest Z in front)'
      twidth=xmax-xmin+1;
      theight=ymax-ymin+1;
      tdepth=zmax-zmin+1;
      twmin=xmin;
      thmin=ymin;
      tdmin=zmin;
      tdir=1;
      projectback=[[mipfact 0 0 xmin*mipfact]; [0 mipfact 0 ymin*mipfact]; [0 0 slicestep zmin]];
      if (slicestep==1) %load in slabs
        nrofslabs=ceil(tdepth/slabthickness);
        sslabbox=zeros(nrofslabs,6);
        slabstart=tdmin:slabthickness:tdmin+tdepth-1;
        for i=1:1:nrofslabs
          sslabbbox(i,:)=[xmin xmax ymin ymax slabstart(i) min([slabstart(i)+slabthickness-1 tdmin+tdepth-1])];
        end;
      else %load each slice individually
        slabc=tdmin:slicestep:tdmin+tdepth-1;
        nrofslabs=size(slabc,2);
        sslabbox=zeros(nrofslabs,6);
        for i=1:1:nrofslabs
          sslabbbox(i,:)=[xmin xmax ymin ymax slabc(i) slabc(i)];
        end;
      end;
    case 6 %'-Z (highest Z in front)'
      twidth=xmax-xmin+1;
      theight=ymax-ymin+1;
      tdepth=zmax-zmin+1;
      twmin=xmin;
      thmin=ymin;
      tdmin=zmin;
      tdir=-1;
      projectback=[[-mipfact 0 0 xmax*mipfact]; [0 mipfact 0 ymin*mipfact]; [0 0 -slicestep zmax]];
      if (slicestep==1) %load in slabs
        nrofslabs=ceil(tdepth/slabthickness);
        sslabbox=zeros(nrofslabs,6);
        slabstart=tdmin:slabthickness:tdmin+tdepth-1;
        slabstart=fliplr(slabstart);
        for i=1:1:nrofslabs
          sslabbbox(i,:)=[xmin xmax ymin ymax slabstart(i) min([slabstart(i)+slabthickness-1 tdmin+tdepth-1])];
        end;
      else %load each slice individually
        slabc=tdmin:slicestep:tdmin+tdepth-1;
        slabc=fliplr(slabc);
        nrofslabs=size(slabc,2);
        sslabbox=zeros(nrofslabs,6);
        for i=1:1:nrofslabs
          sslabbbox(i,:)=[xmin xmax ymin ymax slabc(i) slabc(i)];
        end;
      end;
  end;
      
  %%%%%%%%%%%%%%%%%
  
  rtim=zeros(theight,twidth);
  gtim=zeros(theight,twidth);
  btim=zeros(theight,twidth);
  if (blendmode==4) %min projection: initialize with max
    rtim=rtim+255;
    gtim=gtim+255;
    btim=btim+255;
  end;
  topcolor=zeros(theight,twidth);
  mask=zeros(theight,twidth);
  shadow=ones(theight,twidth);
  ttranspmap=ones(theight,twidth);
  zmap=zeros(theight,twidth)-1;
  
  depth=0;
  
  shadowK = fspecial('disk',shadowcone);
  if (blurdistance>0)
    edgeblurK = fspecial('disk',blurdistance);
  end;
  
  set(vdata.ui.message,'String',{'Generating Projection Image ...','Loading image data ...'});
  pause(0.1);
  
  d=1;
  while ((d<=nrofslabs)&&(vdata.state.lastcancel==0))
    if ((imagesource==3)||(opacitysource==5)||(opacitysource==6))
      %Load screenshots
      [scsimage,res] = vdata.vast.getscreenshotimage(param.miplevel,sslabbbox(d,1),sslabbbox(d,2),sslabbbox(d,3),sslabbbox(d,4),sslabbbox(d,5),sslabbbox(d,6),collapsesegments);
      scsimage=permute(scsimage,[2 1 3 4]);
    else
      scsimage=[];
    end;
    
    opimage=[]; sir=[]; sig=[]; sib=[];
    if ((imagesource==2)||(opacitysource==2)||(opacitysource==4))
      %Load segmentation from selected layer
      sln=selectedsegmentlayernr;
      res=vdata.vast.setselectedlayernr(sln); %set segmentation layer
      res=vdata.vast.setsegtranslation(sltranspre{sln},sltranspost{sln}); %set translation
      [si,res] = vdata.vast.getsegimageRLEdecoded(param.miplevel,sslabbbox(d,1),sslabbbox(d,2),sslabbbox(d,3),sslabbbox(d,4),sslabbbox(d,5),sslabbbox(d,6),0);
      opimage=si;
      if (imagesource==2)
        %translate opimage to rgb
        sir=si;
        sir(si>0)=slcols{sln}(si(si>0),1);
        sig=si;
        sig(si>0)=slcols{sln}(si(si>0),2);
        sib=si;
        sib(si>0)=slcols{sln}(si(si>0),3);
      end;
      
    end;
    if ((imagesource==1)||(opacitysource==1)||(opacitysource==3))
      for slnn=1:length(seglayernrs);
        sln=seglayernrs(slnn);
        %set segmentation layer
        res=vdata.vast.setselectedlayernr(sln);
        %set translation
        res=vdata.vast.setsegtranslation(sltranspre{sln},sltranspost{sln});
        %get data
        [si,res] = vdata.vast.getsegimageRLEdecoded(param.miplevel,sslabbbox(d,1),sslabbbox(d,2),sslabbbox(d,3),sslabbbox(d,4),sslabbbox(d,5),sslabbbox(d,6),0);
        %combine data
        if (min(size(opimage))==0)
          opimage=si;
          %translate opimage to rgb
          sir=si;
          sir(si>0)=slcols{sln}(si(si>0),1);
          sig=si;
          sig(si>0)=slcols{sln}(si(si>0),2);
          sib=si;
          sib(si>0)=slcols{sln}(si(si>0),3);
        else
          opimage(si>0)=si(si>0); %overwrite voxels in earlier layers
          sir(si>0)=slcols{sln}(si(si>0),1);
          sig(si>0)=slcols{sln}(si(si>0),2);
          sib(si>0)=slcols{sln}(si(si>0),3);
        end;
      end;
    end;
    
    opimage(opimage>0)=1;
    if ((opacitysource==3)||(opacitysource==4))
      opimage=1-opimage;
    end;
    sir=double(sir);
    sig=double(sig);
    sib=double(sib);

    %Rotate to target orientation
    switch vdata.data.exportproj.projaxis
    case {1 2} %'+X (lowest X in front)' %'-X (highest X in front)'
      %y->x, z->y, x->z
      if (min(size(opimage))>0)
        opimage=permute(opimage,[2 3 1]);
      end;
      if (min(size(sir))>0)
        sir=permute(sir,[2 3 1]);
      end;
      if (min(size(sig))>0)
        sig=permute(sig,[2 3 1]);
      end;
      if (min(size(sib))>0)
        sib=permute(sib,[2 3 1]);
      end;
      if (min(size(scsimage))>0)
        scsimage=permute(scsimage,[2 3 1 4]);
      end;
    case {3 4} %'+Y (lowest Y in front)' %'-Y (highest Y in front)'
      if (min(size(opimage))>0)
        opimage=permute(opimage,[1 3 2]);
      end;
      if (min(size(sir))>0)
        sir=permute(sir,[1 3 2]);
      end;
      if (min(size(sig))>0)
        sig=permute(sig,[1 3 2]);
      end;
      if (min(size(sib))>0)
        sib=permute(sib,[1 3 2]);
      end;
      if (min(size(scsimage))>0)
        scsimage=permute(scsimage,[1 3 2 4]);
      end;
    case {5 6} %'+Z (lowest Z in front)' %'-Z (highest Z in front)'
      %All fine
    end;
    
    %Go through slab slice by slice
    if (min(size(opimage))>0)
      zlist=1:1:size(opimage,3);
    else
      zlist=1:1:size(scsimage,3);
    end;
    
    if (tdir<0)
      zlist=fliplr(zlist);
    end;

    message={'Generating Projection Image ...',sprintf('Processing slice %d...',depth)};
    set(vdata.ui.message,'String',message);
    pause(0.01);
    
    for i=zlist
      depthattenuate=1-(depth/tdepth);
      depthattenuate=depthattenuate*(1-depthattenuation)+depthattenuation;
      
      %GENERATE IMAGE SOURCE
      rsim=zeros(theight,twidth); gsim=zeros(theight,twidth); bsim=zeros(theight,twidth);
      
      switch imagesource
        case 1 %1: Segmentation (all layers)
          rsim=squeeze(sir(:,:,i))';
          gsim=squeeze(sig(:,:,i))';
          bsim=squeeze(sib(:,:,i))';
        case 2 %2: Segmentation (sel. layer)
          rsim=squeeze(sir(:,:,i))';
          gsim=squeeze(sig(:,:,i))';
          bsim=squeeze(sib(:,:,i))';
        case 3 %3: Screenshots
          if (size(size(scsimage),2)==4)
            rsim=double(squeeze(scsimage(:,:,i,1))');
            gsim=double(squeeze(scsimage(:,:,i,2))');
            bsim=double(squeeze(scsimage(:,:,i,3))');
          else
            rsim=double(squeeze(scsimage(:,:,1))');
            gsim=double(squeeze(scsimage(:,:,2))');
            bsim=double(squeeze(scsimage(:,:,3))');
          end;
      end;
      
      if (expandsegmentation~=0)
        %cheap expand segmentations (uses max)
        simg=uint32(rsim)+256*uint32(gsim)+65536*uint32(bsim);
        simg2=simg;
        for j=1:1:expandsegmentation
          simg2(1:end-1,:)=max(simg2(1:end-1,:), simg2(2:end,:));
          simg2(2:end,:)=max(simg2(1:end-1,:), simg2(2:end,:));
          simg2(:,1:end-1)=max(simg2(:,1:end-1), simg2(:,2:end));
          simg2(:,2:end)=max(simg2(:,1:end-1), simg2(:,2:end));
          simg2(simg~=0)=simg(simg~=0);
        end;
        simg(simg==0)=simg2(simg==0);
        rsim=double(bitand(simg,255));
        gsim=double(bitand(bitshift(simg,-8),255));
        bsim=double(bitand(bitshift(simg,-16),255));
        %end;
      end;
      
      %GENERATE ALPHA SOURCE
      switch opacitysource
        case 1 %Segmented areas, all layers
          stranspmap=ones(theight,twidth);
          opmap=squeeze(opimage(:,:,i))';
          stranspmap(opmap>0)=1-objectopacity;
        case 2 %Segmented areas, selected layer
          stranspmap=ones(theight,twidth);
          opmap=squeeze(opimage(:,:,i))';
          stranspmap(opmap>0)=1-objectopacity;
        case 3 %Unsegmented areas, all layers
          stranspmap=ones(theight,twidth);
          opmap=squeeze(opimage(:,:,i))';
          stranspmap(opmap>0)=1-objectopacity;
        case 4 %Unsegmented areas, selected layer
          stranspmap=ones(theight,twidth);
          opmap=squeeze(opimage(:,:,i))';
          stranspmap(opmap>0)=1-objectopacity;
        case 5 %Screenshots, show bright
          stranspmap=double(squeeze(max(scsimage(:,:,i,:),[],4))')/255;
          stranspmap=1-(stranspmap*objectopacity);
        case 6 %Screenshots, show dark
          stranspmap=1-(double(squeeze(max(scsimage(:,:,i,:),[],4))')/255);
          stranspmap=1-(stranspmap*objectopacity);
        case 7 %Constant
          stranspmap=ones(theight,twidth)*(1-objectopacity);
      end;
      stranspmap(stranspmap>1)=1;
      stranspmap(stranspmap<0)=0;
      
      if (expandsegmentation~=0)
        %cheap expand alpha channel (uses min)
        simg2=stranspmap;
        for j=1:1:expandsegmentation
          simg2(1:end-1,:)=min(simg2(1:end-1,:), simg2(2:end,:));
          simg2(2:end,:)=min(simg2(1:end-1,:), simg2(2:end,:));
          simg2(:,1:end-1)=min(simg2(:,1:end-1), simg2(:,2:end));
          simg2(:,2:end)=min(simg2(:,1:end-1), simg2(:,2:end));
        end;
        stranspmap=simg2;
      end;
      
      if (blurdistance>0)
        stranspmap2 = imfilter(stranspmap,edgeblurK,'same');
        stranspmap2(stranspmap2<0)=0;
        stranspmap2(stranspmap2>1)=1;
        stranspmap(stranspmap2>stranspmap)=stranspmap2(stranspmap2>stranspmap);
      end;
      
      %APPLY DEPTH ATTENUATION
      if (depthattenuate~=1)
        rsim=rsim*depthattenuate;
        gsim=gsim*depthattenuate;
        bsim=bsim*depthattenuate;
      end;
      
      %APPLY SHADOW MAP
      if (vdata.data.exportproj.useshadows)
        rsim=rsim.*shadow;
        gsim=gsim.*shadow;
        bsim=bsim.*shadow;
      end;
      
      %COMBINE WITH TARGET
      switch blendmode
        case 1 %1: Alpha-blend
          rsim=rsim.*(1-stranspmap);
          gsim=gsim.*(1-stranspmap);
          bsim=bsim.*(1-stranspmap);
          rtim=rtim + rsim.*(ttranspmap);  %transpmap is 1 for transparent and 0 for opaque
          gtim=gtim + gsim.*(ttranspmap);
          btim=btim + bsim.*(ttranspmap);
          ttranspmap=ttranspmap.*stranspmap;
        case 2 %2: Additive
          rtim=rtim + rsim.*(1-stranspmap);
          gtim=gtim + gsim.*(1-stranspmap);
          btim=btim + bsim.*(1-stranspmap);
          ttranspmap=ttranspmap.*stranspmap;
        case 3 %3: Maximum projection
          rim=rsim.*(1-stranspmap); rtim(rim>rtim)=rim(rim>rtim);
          gim=gsim.*(1-stranspmap); gtim(gim>gtim)=gim(gim>gtim);
          bim=bsim.*(1-stranspmap); btim(bim>btim)=bim(bim>btim);
          ttranspmap=ttranspmap.*stranspmap;
        case 4 %4: Minimum projection
          rim=rsim.*(1-stranspmap); rtim(rim<rtim)=rim(rim<rtim);
          gim=gsim.*(1-stranspmap); gtim(gim<gtim)=gim(gim<gtim);
          bim=bsim.*(1-stranspmap); btim(bim<btim)=bim(bim<btim);
          ttranspmap=ttranspmap.*stranspmap;
      end;
      
      shadow = imfilter(shadow,shadowK,'same');
      shadow=shadow.*stranspmap;
      zmap((zmap==-1)&(stranspmap<1))=depth;
      depth=depth+1;
    end;

    if (vdata.data.exportproj.showinwindow==1)
      targetimage=zeros(theight,twidth,3);
      targetimage(:,:,1)=rtim;
      targetimage(:,:,2)=gtim;
      targetimage(:,:,3)=btim;
      imshow(targetimage/255,'parent',lax);
      title(lax,sprintf('Rendering in progress; %d of %d ...',d,nrofslabs));
    end;
    d=d+1;
  end;
  
  targetimage=zeros(theight,twidth,3);
  targetimage(:,:,1)=rtim;
  targetimage(:,:,2)=gtim;
  targetimage(:,:,3)=btim;
  
  %%%%%%%%%%%%%%%%%
  
  if (vdata.data.exportproj.finalnormalize)
    maxval=max(targetimage(:));
    targetimage=targetimage/maxval*255;
  end;
  
  targetimage(:,:,1)=targetimage(:,:,1).*(1-ttranspmap)+bgcolor(1)*255*ttranspmap;
  targetimage(:,:,2)=targetimage(:,:,2).*(1-ttranspmap)+bgcolor(2)*255*ttranspmap;
  targetimage(:,:,3)=targetimage(:,:,3).*(1-ttranspmap)+bgcolor(3)*255*ttranspmap;
  
  if ((vdata.data.exportproj.stretchz>1)&&(vdata.data.exportproj.projaxis~=5)&&(vdata.data.exportproj.projaxis~=6))
    mipfakt=bitshift(1,param.miplevel);
    vx=vinfo.voxelsizex*mipfakt;
    aspect=vinfo.voxelsizez/vx;
    txs=size(targetimage,2);
    tys=floor(size(targetimage,1)*aspect);
    if (vdata.data.exportproj.stretchz==2)
      targetimage=imresize(targetimage,[tys txs],'nearest');
      zmap=imresize(zmap,[tys txs],'nearest');
    else
      targetimage=imresize(targetimage,[tys txs]);
      targetimage(targetimage>255)=255; %bicubic interpolation can cause pixel values outside the input range!
      targetimage(targetimage<0)=0;
      zmap=imresize(zmap,[tys txs],'nearest');
    end;
  else
    aspect=1.0;
  end;
  
  switch vdata.data.exportproj.projaxis
    case 1 %'+X (lowest X in front)'
    case 2 %'-X (highest X in front)'
      targetimage=flipdim(targetimage,2);
      zmap=flipdim(zmap,2);
    case 3 %'+Y (lowest Y in front)'
      targetimage=flipdim(targetimage,2);
      zmap=flipdim(zmap,2);
    case 4 %'-Y (highest Y in front)'
    case 5 %'+Z (lowest Z in front)'
    case 6 %'-Z (highest Z in front)'
      targetimage=flipdim(targetimage,2);
      zmap=flipdim(zmap,2);
  end;
  
  if (vdata.data.exportproj.savetofile==1)
    filename =[vdata.data.exportproj.targetfoldername '/' vdata.data.exportproj.targetfilename];
    imwrite(targetimage/255,filename);
  end;

  if (vdata.data.exportproj.showinwindow==0)
    lfig=figure;
    lax=axes;
  end;
  figure(lfig);
  imshow(targetimage/255,'parent',lax);
  if (vdata.state.lastcancel==0)
    title(lax,'Final');
  else
    title(lax,'Canceled');
  end;
  
  %Save parameters of last render for simple navigator
  vdata.data.exportproj.lastimage.image=targetimage;
  vdata.data.exportproj.lastimage.zmap=zmap;
  vdata.data.exportproj.lastimage.stretchz=aspect;
  vdata.data.exportproj.lastimage.region=vdata.data.region;
  vdata.data.exportproj.lastimage.projectback=projectback;
  
  vdata.vast.setsegtranslation([],[]);

  if (vdata.state.lastcancel==0)
    set(vdata.ui.message,'String','Done.');
  else
    set(vdata.ui.message,'String','Canceled.');
  end;
  set(vdata.ui.cancelbutton,'Enable','off');
  vdata.state.lastcancel=0;
  pause(0.1);

  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Volume Measurement Functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
function [] = callback_measurevol(varargin)
  global vdata;

  if (~checkconnection()) return; end;
  vinfo=vdata.vast.getinfo();
  
  if (min([vinfo.datasizex vinfo.datasizey vinfo.datasizez])==0)
    warndlg('ERROR: No volume open in VAST.','VastTools volume measurement');
    return;
  end;
  
  nrofsegments=vdata.vast.getnumberofsegments();
  if (nrofsegments==0)
    warndlg('ERROR: No segmentation available in VAST.','VastTools volume measurement');
    return;
  end;
  
  blockgui();
  
  %Display parameter dialog
  if (~isfield(vdata.data,'region'))
    vdata.data.region.xmin=0;
    vdata.data.region.xmax=vinfo.datasizex-1;
    vdata.data.region.ymin=0;
    vdata.data.region.ymax=vinfo.datasizey-1;
    vdata.data.region.zmin=0; %first slice
    vdata.data.region.zmax=vinfo.datasizez-1; %last slice
  end;
  if (~isfield(vdata.data,'measurevol'))
    vdata.data.measurevol.miplevel=0;
    vdata.data.measurevol.xunit=vinfo.voxelsizex;
    vdata.data.measurevol.yunit=vinfo.voxelsizey;
    vdata.data.measurevol.zunit=vinfo.voxelsizez;
    vdata.data.measurevol.analyzewhich=1;
    vdata.data.measurevol.targetfoldername=[pwd '\'];
    vdata.data.measurevol.targetfilename='volumestats.txt';
  end;
  
  scrsz = get(0,'ScreenSize');
  figheight=350;
  f = figure('units','pixels','position',[50 scrsz(4)-100-figheight 500 figheight],'menubar','none','numbertitle','off','name','VastTools - Measure Segment Volumes','resize','off');

  vpos=figheight-35;
  
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 120 15], 'Tag','t1','String','Analyze at resolution:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  str=cell(vinfo.nrofmiplevels,1);
  vx=vinfo.voxelsizex;
  vy=vinfo.voxelsizey;
  vz=vinfo.voxelsizez;
  for i=1:1:vinfo.nrofmiplevels
    str{i}=sprintf('Mip %d - (%.2f nm, %.2f nm, %.2f nm) voxels',i-1,vx,vy,vz);
    vx=vx*2; vy=vy*2;
  end;
  pmh = uicontrol('Style','popupmenu','String',str,'Value',vdata.data.measurevol.miplevel+1,'Position',[170 vpos 310 20]);
  vpos=vpos-50;
  
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 120 15],'String','Analyze in area:','backgroundcolor',get(f,'color'),'horizontalalignment','left');

  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[340 vpos+10 140 20], 'String','Set to full', 'CallBack',{@callback_region_settofull,0});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[340 vpos-15 140 20], 'String','Set to selected bbox', 'CallBack',{@callback_region_settobbox,0});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[340 vpos-40 140 20], 'String','Set to current voxel', 'CallBack',{@callback_region_settocurrentvoxel,0});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[340 vpos-65 140 20], 'String','Extend to current voxel', 'CallBack',{@callback_region_extendtocurrentvoxel,0});
  
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[130 vpos 100 15],'String','X min:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_xmin = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%d', vdata.data.region.xmin),'horizontalalignment','left');
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[230 vpos 100 15],'String','X max:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_xmax = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[270 vpos 50 20],'String',sprintf('%d',vdata.data.region.xmax),'horizontalalignment','left');
  vpos=vpos-30;
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[130 vpos 100 15],'String','Y min:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_ymin = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%d',vdata.data.region.ymin),'horizontalalignment','left');
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[230 vpos 100 15],'String','Y max:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_ymax = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[270 vpos 50 20],'String',sprintf('%d',vdata.data.region.ymax),'horizontalalignment','left');
  vpos=vpos-30;
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[130 vpos 100 15],'String','Z min:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_zmin = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[170 vpos 50 20],'String',sprintf('%d',vdata.data.region.zmin),'horizontalalignment','left');
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[230 vpos 100 15],'String','Z max:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e_zmax = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[270 vpos 50 20],'String',sprintf('%d',vdata.data.region.zmax),'horizontalalignment','left');
  vpos=vpos-40;
  
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 150 15],'String','Voxel size (full res)  X:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e7 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[150 vpos 60 20],'String',sprintf('%f', vdata.data.measurevol.xunit),'horizontalalignment','left');
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[230 vpos 50 15],'String','Y:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e8 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[250 vpos 60 20],'String',sprintf('%f', vdata.data.measurevol.yunit),'horizontalalignment','left');
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[330 vpos 50 15],'String','Z:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.e9 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[350 vpos 60 20],'String',sprintf('%f', vdata.data.measurevol.zunit),'horizontalalignment','left');

  vpos=vpos-20;
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[60 vpos 400 15], 'Tag','t1','String',sprintf('[VAST reports the voxel size to be: (%.2f nm, %.2f nm, %.2f nm)]',vinfo.voxelsizex,vinfo.voxelsizey,vinfo.voxelsizez),'backgroundcolor',get(f,'color'),'horizontalalignment','left');
  set(t,'tooltipstring','To change, enter the values in VAST under "Info / Volume properties" and save to your EM stack file.');
  vpos=vpos-30;

  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 100 15],'String','Analyze what:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  str=cell(4,1);
  str{1}='All segments individually, uncollapsed';
  str{2}='All segments, collapsed as in VAST';
  str{3}='Selected segment and children, uncollapsed';
  str{4}='Selected segment and children, collapsed as in VAST';
  pmh2 = uicontrol('Style','popupmenu','String',str,'Value',vdata.data.measurevol.analyzewhich,'Position',[120 vpos 290 20]);
  vpos=vpos-30;
  
  t = uicontrol('Style','text', 'Units','Pixels', 'Position',[30 vpos 280 15],'String','Target text file for volume measurement results:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vpos=vpos-25;
  vdata.temp.e10 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[30 vpos 380 20],'String',[vdata.data.measurevol.targetfoldername vdata.data.measurevol.targetfilename],'horizontalalignment','left');
  p1 = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[420 vpos 60 20], 'String','Browse ...','CallBack',{@callback_measurevol_browse});
  vpos=vpos-30;
  
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[150 20 60 20], 'String','OK', 'CallBack',{@callback_done});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[300 20 60 20], 'String','Cancel', 'CallBack',{@callback_canceled});

  vdata.state.lastcancel=1;
  vdata.ui.temp.closefig=0;
  uiwait(f);

  if (vdata.state.lastcancel==0)
    vdata.data.measurevol.miplevel=get(pmh,'value')-1;
    vdata.data.region.xmin = str2num(get(vdata.temp.e_xmin,'String'));
    vdata.data.region.xmax = str2num(get(vdata.temp.e_xmax,'String'));
    vdata.data.region.ymin = str2num(get(vdata.temp.e_ymin,'String'));
    vdata.data.region.ymax = str2num(get(vdata.temp.e_ymax,'String'));
    vdata.data.region.zmin = str2num(get(vdata.temp.e_zmin,'String'));
    vdata.data.region.zmax = str2num(get(vdata.temp.e_zmax,'String'));
    
    vdata.data.measurevol.xunit = str2num(get(vdata.temp.e7,'String'));
    vdata.data.measurevol.yunit = str2num(get(vdata.temp.e8,'String'));
    vdata.data.measurevol.zunit = str2num(get(vdata.temp.e9,'String'));
    vdata.data.measurevol.analyzewhich =get(pmh2,'value');
    vdata.data.measurevol.exportmodestring=get(pmh2,'string');
    vdata.data.measurevol.exportmodestring=vdata.data.measurevol.exportmodestring{vdata.data.measurevol.analyzewhich};
    vdata.data.measurevol.targetfile = get(vdata.temp.e10,'String');
    [vdata.data.measurevol.targetfoldername,vdata.data.measurevol.targetfilename]=splitfilename(vdata.data.measurevol.targetfile);
  end;
  
  if (vdata.ui.temp.closefig==1) %to distinguish close on button press and close on window x
    close(f);
  end;

  if (vdata.state.lastcancel==0)
    measurevolumes();
  end;
  releasegui();
  

function [] = callback_measurevol_browse(varargin)
  global vdata;
  defaultname=[vdata.data.measurevol.targetfoldername vdata.data.measurevol.targetfilename];
  [targetfilename,targetfoldername,filterindex] = uiputfile({'*.txt','Text Files (*.txt)'; '*.*', 'All Files (*.*)'},'Select Target Text File',defaultname);
  if ((~isequal(targetfilename,0)) && (~isequal(targetfoldername,0)))
    set(vdata.temp.e10,'String',[targetfoldername targetfilename]);
    vdata.data.measurevol.targetfilename=targetfilename;
    vdata.data.measurevol.targetfoldername=targetfoldername;
  end;

  
function [foldername,filename]=splitfilename(fullfilename)
  p=size(fullfilename,2);
  while (p>1)&&(fullfilename(p)~='\')&&(fullfilename(p)~='/')
    p=p-1;
  end;
  foldername=fullfilename(1:p);
  filename=fullfilename(p+1:end);

  
function res=measurevolumes()
  global vdata;
  
  if (~checkconnection()) return; end;
  
  set(vdata.ui.cancelbutton,'Enable','on');
  
  miplevel=vdata.data.measurevol.miplevel;
  areaxmin=bitshift(vdata.data.region.xmin,-miplevel);
  areaxmax=bitshift(vdata.data.region.xmax+1,-miplevel)-1;
  areaymin=bitshift(vdata.data.region.ymin,-miplevel);
  areaymax=bitshift(vdata.data.region.ymax+1,-miplevel)-1;
  areazmin=vdata.data.region.zmin;
  areazmax=vdata.data.region.zmax;
  
  tilesizex=1024;
  tilesizey=1024;
  tilesizez=64;
  
  tilestartx=[areaxmin:tilesizex:areaxmax];
  tilestarty=[areaymin:tilesizey:areaymax];
  tilestartz=[areazmin:tilesizez:areazmax];
  nrxtiles=size(tilestartx,2);
  nrytiles=size(tilestarty,2);
  nrztiles=size(tilestartz,2);
  
  analyzewhich=vdata.data.measurevol.analyzewhich;
  
  data=vdata.vast.getallsegmentdatamatrix();
  name=vdata.vast.getallsegmentnames();
  name(1)=[];  %remove 'Background'
  
  % Compute list of objects to export
  switch analyzewhich
    case 1  %All segments individually, uncollapsed
      objects=uint32([data(:,1) data(:,2)]); 
      vdata.vast.setsegtranslation([],[]);

    case 2  %All segments, collapsed as in Vast
      %4: Collapse segments as in the view during segment text file exporting
      objects=unique(data(:,18));
      objects=uint32([objects data(objects,2)]);
      vdata.vast.setsegtranslation(data(:,1),data(:,18));
      
    case 3  %Selected segment and children, uncollapsed
      selected=find(bitand(data(:,2),65536)>0);
      if (min(size(selected))==0)
        objects=uint32([data(:,1) data(:,2)]); 
      else
        selected=[selected getchildtreeids(data,selected)];
        objects=uint32([selected' data(selected,2)]);
      end;
      vdata.vast.setsegtranslation(data(selected,1),data(selected,1));
      
    case 4  %Selected segment and children, collapsed as in Vast
      selected=find(bitand(data(:,2),65536)>0);
      if (min(size(selected))==0)
        %None selected: choose all, collapsed
        selected=data(:,1);
        objects=unique(data(:,18));
      else
        selected=[selected getchildtreeids(data,selected)];
        objects=unique(data(selected,18));
      end;

      objects=uint32([objects data(objects,2)]);
      vdata.vast.setsegtranslation(data(selected,1),data(selected,18));
  end;
  
  nrvox=zeros(max(objects(:,1)),1);
  
  z=1;
  while ((z<=size(tilestartz,2))&&(vdata.state.lastcancel==0))
    minz=tilestartz(z); maxz=min([tilestartz(z)+tilesizez-1 areazmax]);
    y=1;
    while ((y<=size(tilestarty,2))&&(vdata.state.lastcancel==0))
      miny=tilestarty(y); maxy=min([tilestarty(y)+tilesizey-1 areaymax]);
      x=1;
      while ((x<=size(tilestartx,2))&&(vdata.state.lastcancel==0))
        minx=tilestartx(x); maxx=min([tilestartx(x)+tilesizex-1 areaxmax]);
        
        message={'Measuring Volumes ...',sprintf('Loading Segmentation Cube (%d,%d,%d) of (%d,%d,%d)...',x,y,z,nrxtiles,nrytiles,nrztiles)};
        set(vdata.ui.message,'String',message);
        pause(0.01);
        
        %Volumes
        [v,n,res] = vdata.vast.getRLEcountunique(miplevel,minx,maxx,miny,maxy,minz,maxz,0);
        if (res==1)
          n(v==0)=[];
          v(v==0)=[];
          if (min(size(v))>0)
            nrvox(v)=nrvox(v)+n;
          end;
        end;
        x=x+1;
      end;
      y=y+1;
    end;
    z=z+1;
  end;
  
  nrvox=nrvox(objects(:,1));
  
  vdata.data.measurevol.lastobjects=objects;
  vdata.data.measurevol.lastvolume=nrvox;
  
  vdata.vast.setsegtranslation([],[]);
  
  if (vdata.state.lastcancel==0)
    %write surface area values to text file
    mipfact=bitshift(1,vdata.data.measurevol.miplevel);
    voxsizex=vdata.data.measurevol.xunit*mipfact;
    voxsizey=vdata.data.measurevol.yunit*mipfact;
    voxsizez=vdata.data.measurevol.zunit;
    voxelvol=voxsizex*voxsizey*voxsizez;
    fid = fopen(vdata.data.measurevol.targetfile, 'wt');
    if (fid>0)
      fprintf(fid,'%% VastTools Object Volume Export\n');
      fprintf(fid,'%% Provided as-is, no guarantee for correctness!\n');
      fprintf(fid,'%% %s\n\n',get(vdata.fh,'name'));
      
      fprintf(fid,'%% Source File: %s\n',getselectedseglayername());
      fprintf(fid,'%% Mode: %s\n', vdata.data.measurevol.exportmodestring);
      fprintf(fid,'%% Area: (%d-%d, %d-%d, %d-%d)\n',areaxmin,areaxmax,areaymin,areaymax,areazmin,areazmax);
      fprintf(fid,'%% Computed at voxel size: (%f,%f,%f)\n',voxsizex,voxsizey,voxsizez);
      fprintf(fid,'%% Columns are: Object Name, Object ID, Voxel Count, Object Volume\n\n');

      for segnr=1:1:size(objects,1)
        seg=objects(segnr,1);
        fprintf(fid,'"%s"  %d  %d  %f\n',name{seg},seg,nrvox(segnr),nrvox(segnr)*voxelvol);
      end;
      fprintf(fid,'\n');
      fclose(fid);
    else
      warndlg(['WARNING: Could not open "' vdata.data.measurevol.targetfile '" for writing.'],'Saving volumes failed!');
    end;
  end;
  
  if (vdata.state.lastcancel==0)
    set(vdata.ui.message,'String','Done.');
  else
    set(vdata.ui.message,'String','Canceled.');
  end;
  set(vdata.ui.cancelbutton,'Enable','off');
  vdata.state.lastcancel=0;
  

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Euclidian Measurement Tool

function [] = callback_euclidiantool(varargin)
  global vdata;
  
  if (~checkconnection()) return; end;
  
  %Check if tool already open
  if (ishandle(vdata.etfh))
    figure(vdata.etfh);
    return;
  end;
  
  if (isfield('vdata','temp')==0)
    vdata.temp.et.c1=[0 0 0];
  end;
  if (isfield('vdata.temp','et')==0)
    vdata.temp.et.c1=[0 0 0];
    vdata.temp.et.voxelsize=[1 1 1];
    if (vdata.state.isconnected)
      [x,y,z]=vdata.vast.getviewcoordinates();
      vdata.temp.et.c1=[x y z];
      vinfo=vdata.vast.getinfo();
      vdata.temp.et.voxelsize=[vinfo.voxelsizex vinfo.voxelsizey vinfo.voxelsizez];
    end;
    vdata.temp.et.c2=[0 0 0];
    c1=double(vdata.temp.et.c1); c2=double(vdata.temp.et.c2);
    vdata.temp.et.voxdist=sqrt(sum((c1-c2).*(c1-c2)));
    c1nm=c1.*double(vdata.temp.et.voxelsize); c2nm=c2.*double(vdata.temp.et.voxelsize);
    vdata.temp.et.nmdist=sqrt(sum((c1nm-c2nm).*(c1nm-c2nm)));
  end;
  
  %blockgui();
  scrsz = get(0,'ScreenSize');
  figheight=190;
  f = figure('units','pixels','position',[50 scrsz(4)-100-figheight 440 figheight],'menubar','none','numbertitle','off','name','VastTools - Euclidian Distance Measurement','resize','off');
  vdata.etfh=f;
  vpos=figheight-40;
  
  c1=vdata.temp.et.c1; c2=vdata.temp.et.c2; vs=vdata.temp.et.voxelsize;

  uicontrol('Style','text', 'Units','Pixels', 'Position',[20 vpos 150 15],'String','First Coordinate:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.et.e1 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[180 vpos 140 20],'String',sprintf('(%d, %d, %d)',c1(1),c1(2),c1(3)),'horizontalalignment','left');
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[330 vpos 40 20], 'String','Get', 'CallBack',{@callback_et_get1});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[380 vpos 40 20], 'String','GO!', 'CallBack',{@callback_et_go1});
  vpos=vpos-30;
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[20 vpos 150 15],'String','Second Coordinate:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.et.e2 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[180 vpos 140 20],'String',sprintf('(%d, %d, %d)',c2(1),c2(2),c2(3)),'horizontalalignment','left');
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[330 vpos 40 20], 'String','Get', 'CallBack',{@callback_et_get2});
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[380 vpos 40 20], 'String','GO!', 'CallBack',{@callback_et_go2}); 
  vpos=vpos-30;
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[20 vpos 150 15],'String','Voxel Size:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.et.e3 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[180 vpos 140 20],'String',sprintf('(%.02f, %.02f, %.02f)',vs(1),vs(2),vs(3)),'horizontalalignment','left');
  p = uicontrol('Style','PushButton', 'Units','Pixels', 'Position',[330 vpos 60 20], 'String','Update', 'CallBack',{@callback_et_getvoxelsize});
  vpos=vpos-30;
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[20 vpos 170 15],'String','Euclidian Distance in Voxels:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.et.e4 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[180 vpos 130 20],'String',sprintf('%f',vdata.temp.et.voxdist),'horizontalalignment','left');
  vpos=vpos-30;
  
  uicontrol('Style','text', 'Units','Pixels', 'Position',[20 vpos 170 15],'String','Euclidian Distance in nm:','backgroundcolor',get(f,'color'),'horizontalalignment','left');
  vdata.temp.et.e5 = uicontrol('Style','Edit', 'Units','Pixels', 'Position',[180 vpos 130 20],'String',sprintf('%f',vdata.temp.et.nmdist),'horizontalalignment','left');

  set(vdata.ui.menu.euclidiantool,'checked','on');
  uiwait(f);
  
  set(vdata.ui.menu.euclidiantool,'checked','off');

  
function [] = callback_et_go1(varargin)
  global vdata;
  if (~checkconnection()) return; end;
  
  if (vdata.state.isconnected)
    x=vdata.temp.et.c1(1);
    y=vdata.temp.et.c1(2);
    z=vdata.temp.et.c1(3);
    vdata.vast.setviewcoordinates(x,y,z);
  else
    warndlg('ERROR: Not connected to VAST. please connect before using this function.','Not connected to VAST');
  end;  

function [] = callback_et_go2(varargin)
  global vdata;
  if (~checkconnection()) return; end;
    
  if (vdata.state.isconnected)
    x=vdata.temp.et.c2(1);
    y=vdata.temp.et.c2(2);
    z=vdata.temp.et.c2(3);
    vdata.vast.setviewcoordinates(x,y,z);
  else
    warndlg('ERROR: Not connected to VAST. please connect before using this function.','Not connected to VAST');
  end;  

function [] = callback_et_get1(varargin)
  global vdata;
  if (~checkconnection()) return; end;
  
  if (vdata.state.isconnected)
    [x,y,z]=vdata.vast.getviewcoordinates();
    vdata.temp.et.c1=[x y z];
    set(vdata.temp.et.e1,'string',sprintf('(%d, %d, %d)',x,y,z));
    c1=double(vdata.temp.et.c1); c2=double(vdata.temp.et.c2);
    vdata.temp.et.voxdist=sqrt(sum((c1-c2).*(c1-c2)));
    set(vdata.temp.et.e4,'String',sprintf('%f',vdata.temp.et.voxdist));
    c1nm=c1.*double(vdata.temp.et.voxelsize); c2nm=c2.*double(vdata.temp.et.voxelsize);
    vdata.temp.et.nmdist=sqrt(sum((c1nm-c2nm).*(c1nm-c2nm)));
    set(vdata.temp.et.e5,'String',sprintf('%f',vdata.temp.et.nmdist));
  else
    warndlg('ERROR: Not connected to VAST. please connect before using this function.','Not connected to VAST');
  end;
  
function [] = callback_et_get2(varargin)
  global vdata;
  if (~checkconnection()) return; end;
  
  if (vdata.state.isconnected)
    [x,y,z]=vdata.vast.getviewcoordinates();
    vdata.temp.et.c2=[x y z];
    set(vdata.temp.et.e2,'string',sprintf('(%d, %d, %d)',x,y,z));
    c1=double(vdata.temp.et.c1); c2=double(vdata.temp.et.c2);
    vdata.temp.et.voxdist=sqrt(sum((c1-c2).*(c1-c2)));
    set(vdata.temp.et.e4,'String',sprintf('%f',vdata.temp.et.voxdist));
    c1nm=c1.*double(vdata.temp.et.voxelsize); c2nm=c2.*double(vdata.temp.et.voxelsize);
    vdata.temp.et.nmdist=sqrt(sum((c1nm-c2nm).*(c1nm-c2nm)));
    set(vdata.temp.et.e5,'String',sprintf('%f',vdata.temp.et.nmdist));
  else
    warndlg('ERROR: Not connected to VAST. please connect before using this function.','Not connected to VAST');
  end;
  
function [] = callback_et_getvoxelsize(varargin)
  global vdata;
  if (~checkconnection()) return; end;
  
  if (vdata.state.isconnected)
    vinfo=vdata.vast.getinfo();
    vdata.temp.et.voxelsize=[vinfo.voxelsizex vinfo.voxelsizey vinfo.voxelsizez];
    vs=vdata.temp.et.voxelsize;
    set(vdata.temp.et.e3,'String',sprintf('(%.02f, %.02f, %.02f)',vs(1),vs(2),vs(3)));
    c1=double(vdata.temp.et.c1); c2=double(vdata.temp.et.c2);
    vdata.temp.et.voxdist=sqrt(sum((c1-c2).*(c1-c2)));
    set(vdata.temp.et.e4,'String',sprintf('%f',vdata.temp.et.voxdist));
    c1nm=c1.*double(vdata.temp.et.voxelsize); c2nm=c2.*double(vdata.temp.et.voxelsize);
    vdata.temp.et.nmdist=sqrt(sum((c1nm-c2nm).*(c1nm-c2nm)));
    set(vdata.temp.et.e5,'String',sprintf('%f',vdata.temp.et.nmdist));
  else
    warndlg('ERROR: Not connected to VAST. please connect before using this function.','Not connected to VAST');
  end;
 
  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Target List Functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [] = callback_newtargetlist(varargin)
  global vdata;
  
  name = inputdlg({'Enter Target List Name:'},'VastTools - New Target List',1,{'VAST Targets'});
  targetlistname=name{1};
  vdata.data.nroftargetlists=vdata.data.nroftargetlists+1;
  targetlistwindow(targetlistname,vdata.data.nroftargetlists,[]);
  
  
function [] = callback_loadtargetlist(varargin)
  global vdata;  
  
[filename, pathname] = uigetfile({'*.mat';'*.*'},'Select target list file to open...');
  if (filename==0)
    %'Cancel' was pressed. Don't load.
    return;
  end;

  vdata.data.nroftargetlists=vdata.data.nroftargetlists+1;
  targetlistwindow([],vdata.data.nroftargetlists,[pathname filename]);
  
  
function [] = targetlistwindow(targetlistname, instance, inputfilename)
  global vdata;
  
  scrsz = get(0,'ScreenSize');
  vdata.data.tl(instance).fh = figure('units','pixels','outerposition',[300 scrsz(4)-639-300 1024 640],...
    'menubar','none','numbertitle','off','resize','on','name',[targetlistname ' [VastTools Target List]']);
  set(vdata.data.tl(instance).fh,'CloseRequestFcn',{@callback_tlquit, instance});
  set(vdata.data.tl(instance).fh,'ResizeFcn',{@callback_tlresize, instance});
  vdata.data.tl(instance).open=1;
  
  vdata.data.tl(instance).menu.file = uimenu(vdata.data.tl(instance).fh,'Label','File');
  vdata.data.tl(instance).menu.savetargetlist = uimenu(vdata.data.tl(instance).menu.file,'Label','Save Target List ...','Callback',{@callback_savetargetlist, instance});
  vdata.data.tl(instance).menu.close = uimenu(vdata.data.tl(instance).menu.file,'Label','Close Target List','Callback',{@callback_tlquit, instance});
  
  vdata.data.tl(instance).menu.edit = uimenu(vdata.data.tl(instance).fh,'Label','Edit');
  vdata.data.tl(instance).menu.cutselectedrows = uimenu(vdata.data.tl(instance).menu.edit,'Label','Cut Selected Rows','Callback',{@callback_tlcutselectedrows, instance});
  vdata.data.tl(instance).menu.copyselectedrows = uimenu(vdata.data.tl(instance).menu.edit,'Label','Copy Selected Rows','Callback',{@callback_tlcopyselectedrows, instance});
  vdata.data.tl(instance).menu.pasteselectedrows = uimenu(vdata.data.tl(instance).menu.edit,'Label','Paste Rows Below Selected','Callback',{@callback_tlpasteselectedrows, instance});
  vdata.data.tl(instance).menu.insertseparator = uimenu(vdata.data.tl(instance).menu.edit,'Label','Insert Separator Below Selected Row','Separator','on','Callback',{@callback_tlinsertseparator, instance});
  vdata.data.tl(instance).menu.insertcoords = uimenu(vdata.data.tl(instance).menu.edit,'Label','Import Coordinates From Matlab Matrix','Separator','on','Callback',{@callback_tlinsertcoords, instance});

  
  columnname =   {'Click', '       Coordinates       ', 'Zoom', 'Sel. Segnr', '   Target Name   ', '     Properties     ', '       Notes       ', '       Comments       '};
  columnformat = {'char', 'char', 'char', 'char', 'char', 'char', 'char', 'char'};
  columneditable =  [false false false false true true true true];
  
  vdata.data.tl(instance).sendzoom=1;
  vdata.data.tl(instance).sendselected=1;

  pos=get(vdata.data.tl(instance).fh,'Position');
  
  vdata.data.tl(instance).ui.addbutton = uicontrol('style','push','units','pixels','position',[150 pos(4)-65 250 30],...
    'fontsize',12,'string','Add Current VAST Location','callback',{@callback_tladdcurrentlocation, instance});
  
  vdata.data.tl(instance).ui.updatebutton = uicontrol('style','push','units','pixels','position',[420 pos(4)-65 250 30],...
    'fontsize',12,'string','Update First Selected','callback',{@callback_tlupdateselected, instance});
  
  vdata.data.tl(instance).ui.sendzoom = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[10 pos(4)-45 100 15],'Value',vdata.data.tl(instance).sendzoom,'string','Update Zoom','backgroundcolor',get(vdata.data.tl(instance).fh,'color'),'callback',{@callback_tlsendzoom, instance});
  vdata.data.tl(instance).ui.sendselect = uicontrol('Style','checkbox', 'Units','Pixels', 'Position',[10 pos(4)-65 100 15],'Value',vdata.data.tl(instance).sendselected,'string','Update Segnr','backgroundcolor',get(vdata.data.tl(instance).fh,'color'),'callback',{@callback_tlsendselected, instance});
  
  vdata.data.tl(instance).ui.table = uitable('Units','pixels','Position', [10 10 pos(3)-20 pos(4)-80],'ColumnName', columnname, ...
    'ColumnFormat', columnformat, 'ColumnEditable', columneditable, 'RowName',[], ...
    'CellSelectionCallback',{@callback_tlcellselection, instance}, 'CellEditCallback',{@callback_tlcelledit, instance}, 'ButtonDownFcn',{@callback_tltablerightclick, instance});

  vdata.data.tl(instance).selected=[];
  vdata.data.tl(instance).filename=inputfilename;
  vdata.data.tl(instance).targetlistname=targetlistname;
  
  if (min(size(inputfilename>0)))
    %Load data
    targetlist=load(inputfilename,'-mat','targetlist');
    if (~isfield(targetlist,'targetlist'))
      warndlg('This is not a valid target list file. A .MAT file with struct "targetlist" is expected.',['Error loading ' inputfilename]);
      return;
    end;
    targetlist=targetlist.targetlist;
    
    if (~isfield(targetlist,'coords'))
      warndlg('"targetlist.coords" missing in target list file.',['Error loading ' inputfilename]);
      callback_tlquit();
      return;
    end;
    
    targetlist.coords=double(targetlist.coords);
    nroftargets=size(targetlist.coords,1);

    if (~isfield(targetlist,'name'))
      for i=1:1:nroftargets
        targetlist.name{i}=sprintf('Target %d',i);
      end;
    end;
    if (~isfield(targetlist,'segmentnr'))
      for i=1:1:nroftargets
        targetlist.segmentnr(i)=-1;
      end;
    end;
    if (~isfield(targetlist,'properties'))
      for i=1:1:nroftargets
        targetlist.properties{i}='';
      end;
    end;
    if (~isfield(targetlist,'notes'))
      for i=1:1:nroftargets
        targetlist.notes{i}='';
      end;
    end;
    if (~isfield(targetlist,'comments'))
      for i=1:1:nroftargets
        targetlist.comments{i}='';
      end;
    end;

    vdata.data.tl(instance).nroftargets=nroftargets;
    vdata.data.tl(instance).coords=targetlist.coords;
    vdata.data.tl(instance).name=targetlist.name;
    vdata.data.tl(instance).segmentnr=targetlist.segmentnr;
    vdata.data.tl(instance).properties=targetlist.properties;
    vdata.data.tl(instance).notes=targetlist.notes;
    vdata.data.tl(instance).comments=targetlist.comments;
    
    set(vdata.data.tl(instance).fh,'name',[inputfilename '  [VastTools Target List]']);
    
    sz=size(vdata.data.tl(instance).segmentnr);
    if (sz(2)>sz(1)) 
      vdata.data.tl(instance).segmentnr = vdata.data.tl(instance).segmentnr'; 
    end;
    
  else
    vdata.data.tl(instance).nroftargets=0;
    vdata.data.tl(instance).coords=[];
    vdata.data.tl(instance).name={};
    vdata.data.tl(instance).segmentnr=[];
    vdata.data.tl(instance).properties={};
    vdata.data.tl(instance).notes={};
    vdata.data.tl(instance).comments={};
  end;
  vdata.data.tl(instance).ischanged=0;
  tl_updatetable(instance);
  
  
function tl_updatetable(instance)
  global vdata;

  separatorstring='<html><body bgcolor="#C0C0A6"><b>........................................</b></body></html>';

  nroftargets=vdata.data.tl(instance).nroftargets;
  if (nroftargets==0)
    dat=[];
    set(vdata.data.tl(instance).ui.table,'Data', dat);
    vdata.data.tl(instance).ui.tabledata=dat;
    return;
  end;
  
  dat=cell(nroftargets,3);
  targetlist.coords=vdata.data.tl(instance).coords;
  targetlist.name=vdata.data.tl(instance).name;
  targetlist.segmentnr=vdata.data.tl(instance).segmentnr;
  targetlist.properties=vdata.data.tl(instance).properties;
  targetlist.notes=vdata.data.tl(instance).notes;
  targetlist.comments=vdata.data.tl(instance).comments;
  
  for i=1:1:nroftargets
    if (~isnan(targetlist.coords(i,1)))
      dat{i,1}='GO!';
      dat{i,2}=sprintf('(%d, %d, %d)',targetlist.coords(i,1),targetlist.coords(i,2),targetlist.coords(i,3));
      dat{i,3}=sprintf('%d',targetlist.coords(i,4));
      dat{i,4}=targetlist.segmentnr(i);
      dat{i,5}=targetlist.name{i};
      dat{i,6}=targetlist.properties{i};
      dat{i,7}=targetlist.notes{i};
      dat{i,8}=targetlist.comments{i};
    else
      dat{i,1}= separatorstring;
      dat{i,2}= separatorstring;
      dat{i,3}= separatorstring;
      dat{i,4}= separatorstring;
      dat{i,5}=targetlist.name{i};
      dat{i,6}=targetlist.properties{i};
      dat{i,7}=targetlist.notes{i};
      dat{i,8}=targetlist.comments{i};
    end;
  end;
  
  set(vdata.data.tl(instance).ui.table,'Data', dat);
  vdata.data.tl(instance).ui.tabledata=dat;
  
  
function [] = callback_tlquit(varargin)
  global vdata;
  instance=varargin{3};
  
  if (vdata.data.tl(instance).ischanged==1)
    res = questdlg('This target list was changed. Close without saving?','Close Target List','Yes','No','Yes');
    if strcmp(res,'No') 
      return; 
    end
  end;
  
  %%%% CLEANUP
  if ishandle(vdata.data.tl(instance).fh) 
    delete(vdata.data.tl(instance).fh); 
  end
  vdata.data.tl(instance).open=0;
  vdata.data.tl(instance).fh=[];
  
  
function [] = callback_tlresize(varargin)
  global vdata;
  instance=varargin{3};
  
  set(vdata.data.tl(instance).fh,'Units','pixels');
  pos = get(vdata.data.tl(instance).fh,'OuterPosition');
  hpos=pos(3)+(-1024+560);
  vpos=pos(4)-100;
  pos=get(vdata.data.tl(instance).fh,'Position');
  
  set(vdata.data.tl(instance).ui.addbutton,'position',[150 pos(4)-40 250 30]);
  set(vdata.data.tl(instance).ui.updatebutton,'position',[420 pos(4)-40 250 30]);
  set(vdata.data.tl(instance).ui.sendzoom,'Position',[10 pos(4)-25 100 15]);
  set(vdata.data.tl(instance).ui.sendselect,'Position',[10 pos(4)-40 100 15]);
  set(vdata.data.tl(instance).ui.table,'Position', [10 10 pos(3)-20 pos(4)-60]);
  
  
function [] = callback_savetargetlist(varargin)
  global vdata;
  instance=varargin{3};
  
  if (min(size(vdata.data.tl(instance).filename>0)))
    targetname=[vdata.data.tl(instance).filename];
  else
    targetname=[vdata.data.tl(instance).targetlistname '.mat'];
  end;
  [filename, pathname] = uiputfile({'*.mat';'*.*'},'Select target list file to save...',targetname);
  if (filename==0)
    %'Cancel' was pressed. Don't save.
    return;
  end;
  
  targetlist.coords=vdata.data.tl(instance).coords;
  targetlist.name=vdata.data.tl(instance).name;
  targetlist.segmentnr=vdata.data.tl(instance).segmentnr;
  targetlist.properties=vdata.data.tl(instance).properties;
  targetlist.notes=vdata.data.tl(instance).notes;
  targetlist.comments=vdata.data.tl(instance).comments;

  save([pathname filename],'targetlist');
  vdata.data.tl(instance).filename=[pathname filename];
  set(vdata.data.tl(instance).fh,'name',[vdata.data.tl(instance).filename '  [VastTools Target List]']);
  vdata.data.tl(instance).ischanged=0;
  
function [] = callback_tlsendzoom(varargin)
  global vdata;
  instance=varargin{3};   
  
  if (get(vdata.data.tl(instance).ui.sendzoom,'Value') == get(vdata.data.tl(instance).ui.sendzoom,'Max'))
	  vdata.data.tl(instance).sendzoom=1;
  else
    vdata.data.tl(instance).sendzoom=0;
  end
  
    
function [] = callback_tlsendselected(varargin)
  global vdata;
  instance=varargin{3};
  
  if (get(vdata.data.tl(instance).ui.sendselect,'Value') == get(vdata.data.tl(instance).ui.sendselect,'Max'))
	  vdata.data.tl(instance).sendselected=1;
  else
    vdata.data.tl(instance).sendselected=0;
  end
  

function [] = callback_tlcelledit(varargin)
  global vdata;
  instance=varargin{3};
  
  row=varargin{2}.Indices(1);
  col=varargin{2}.Indices(2);
  if (col==5) %target name
    vdata.data.tl(instance).name{row}=varargin{2}.NewData;
  end;
  if (col==6) %notes
    vdata.data.tl(instance).properties{row}=varargin{2}.NewData;
  end;
  if (col==7) %notes
    vdata.data.tl(instance).notes{row}=varargin{2}.NewData;
  end;
  if (col==8) %comments
    vdata.data.tl(instance).comments{row}=varargin{2}.NewData;
  end;
  vdata.data.tl(instance).ischanged=1;
  
  
function [] = callback_tlcellselection(varargin)
  %Callback for click into target list
  global vdata;
  instance=varargin{3};
  
  if (~checkconnection()) return; end;
  
  selected = varargin{2}.Indices;
  
  vdata.data.tl(instance).selected=selected;
  if (min(size(selected))>0)
    if (selected(1,2)==1)
      tcoords=vdata.data.tl(instance).coords(selected(1,1),:);
      if (~isnan(tcoords(1)))
        if (vdata.state.isconnected)
          vdata.vast.setviewcoordinates(tcoords(1),tcoords(2),tcoords(3));
          if (vdata.data.tl(instance).sendzoom==1)
            vdata.vast.setviewzoom(tcoords(4));
          end;
          if (vdata.data.tl(instance).sendselected==1)
            vdata.vast.setselectedsegmentnr(vdata.data.tl(instance).segmentnr(selected(1,1)));
          end;
        else
          warndlg('ERROR: Not connected to VAST. please connect before using this function.','Not connected to VAST');
        end;
      end;
    end;
  end;


function [] = callback_tladdcurrentlocation(varargin)
  global vdata;
  instance=varargin{3};
  
  if (~checkconnection()) return; end;
  
  if (vdata.state.isconnected)
    [tcoords(1),tcoords(2),tcoords(3)]=vdata.vast.getviewcoordinates();
    zoom=vdata.vast.getviewzoom();
    selectedsegmentnr=vdata.vast.getselectedsegmentnr();
    if (selectedsegmentnr == -1)
      selectedsegmentnr=0;
    end;
    
    ins=size(vdata.data.tl(instance).coords,1);
    selected=vdata.data.tl(instance).selected;
    if (min(size(selected))>0)
      rowlist=unique(selected(:,1));
      ins=rowlist(end);
    end;
  
    vdata.data.tl(instance).nroftargets = vdata.data.tl(instance).nroftargets+1;
    vdata.data.tl(instance).coords = [vdata.data.tl(instance).coords(1:ins,:); double([tcoords zoom]); vdata.data.tl(instance).coords(ins+1:end,:)];
    vdata.data.tl(instance).name = [vdata.data.tl(instance).name(1:ins); sprintf('Target %d',vdata.data.tl(instance).nroftargets); vdata.data.tl(instance).name(ins+1:end)];
    vdata.data.tl(instance).segmentnr = [vdata.data.tl(instance).segmentnr(1:ins); selectedsegmentnr; vdata.data.tl(instance).segmentnr(ins+1:end)];
    vdata.data.tl(instance).properties = [vdata.data.tl(instance).properties(1:ins); ' '; vdata.data.tl(instance).properties(ins+1:end)];
    vdata.data.tl(instance).notes = [vdata.data.tl(instance).notes(1:ins); ' '; vdata.data.tl(instance).notes(ins+1:end)];
    vdata.data.tl(instance).comments = [vdata.data.tl(instance).comments(1:ins); ' '; vdata.data.tl(instance).comments(ins+1:end)];
    vdata.data.tl(instance).ischanged=1;
    tl_updatetable(instance);    
    
  else
    warndlg('ERROR: Not connected to VAST. please connect before using this function.','Not connected to VAST');
  end;

  
function [] = callback_tlupdateselected(varargin)
  global vdata;
  instance=varargin{3};
  
  if (~checkconnection()) return; end;
  
  if (vdata.state.isconnected)
    info=vdata.vast.getinfo();
    [tcoords(1),tcoords(2),tcoords(3)]=vdata.vast.getviewcoordinates();
    zoom=vdata.vast.getviewzoom();
    selectedsegmentnr=vdata.vast.getselectedsegmentnr();
    
    ins=size(vdata.data.tl(instance).coords,1);
    selected=vdata.data.tl(instance).selected;
    if (min(size(selected))>0)
      rowlist=unique(selected(:,1));
      ins=rowlist(end);
    end;
    
    if (vdata.data.tl(instance).sendzoom~=1)
      zoom=vdata.data.tl(instance).coords(ins,4);
    end;
    
    if (vdata.data.tl(instance).sendselected~=1)
      selectedsegmentnr=vdata.data.tl(instance).segmentnr(ins);
    end;
    
    vdata.data.tl(instance).coords(ins,:)= double([tcoords zoom]);
    if (selectedsegmentnr > -1)
      vdata.data.tl(instance).segmentnr(ins)= selectedsegmentnr;
    end;
    vdata.data.tl(instance).ischanged=1;
    tl_updatetable(instance);  
    
  else
    warndlg('ERROR: Not connected to VAST. please connect before using this function.','Not connected to VAST');
  end;
  
  
  
  
function [] = callback_tlinsertseparator(varargin)
  global vdata;
  instance=varargin{3};
  
  selected=vdata.data.tl(instance).selected;
  separatorstring='<html><body bgcolor="#C0C0A6"><b>........................................</b></body></html>';
  
  if (min(size(selected))>0)
    rowlist=unique(selected(:,1));
    ins=rowlist(end);
    vdata.data.tl(instance).nroftargets = vdata.data.tl(instance).nroftargets+1;
    vdata.data.tl(instance).coords = [vdata.data.tl(instance).coords(1:ins,:); [nan nan nan nan]; vdata.data.tl(instance).coords(ins+1:end,:)];
    vdata.data.tl(instance).name = [vdata.data.tl(instance).name(1:ins); separatorstring; vdata.data.tl(instance).name(ins+1:end)];
    vdata.data.tl(instance).segmentnr = [vdata.data.tl(instance).segmentnr(1:ins); 0; vdata.data.tl(instance).segmentnr(ins+1:end)];
    vdata.data.tl(instance).properties = [vdata.data.tl(instance).properties(1:ins); separatorstring; vdata.data.tl(instance).properties(ins+1:end)];
    vdata.data.tl(instance).notes = [vdata.data.tl(instance).notes(1:ins); separatorstring; vdata.data.tl(instance).notes(ins+1:end)];
    vdata.data.tl(instance).comments = [vdata.data.tl(instance).comments(1:ins); separatorstring; vdata.data.tl(instance).comments(ins+1:end)];
  else
    %nothing selected: append
    vdata.data.tl(instance).nroftargets = vdata.data.tl(instance).nroftargets+1;
    vdata.data.tl(instance).coords = [vdata.data.tl(instance).coords; [nan nan nan nan]];
    vdata.data.tl(instance).name = [vdata.data.tl(instance).name; separatorstring];
    vdata.data.tl(instance).segmentnr = [vdata.data.tl(instance).segmentnr; 0];
    vdata.data.tl(instance).properties = [vdata.data.tl(instance).properties; separatorstring];
    vdata.data.tl(instance).notes = [vdata.data.tl(instance).notes; separatorstring];
    vdata.data.tl(instance).comments = [vdata.data.tl(instance).comments; separatorstring];
  end;
  vdata.data.tl(instance).ischanged=1;
  tl_updatetable(instance);
  
  
function [] = callback_tlinsertcoords(varargin)
  global vdata;
  instance=varargin{3};
  
  selected=vdata.data.tl(instance).selected;
  ins=0;
  if (min(size(selected))>0)
    ins=selected(end,1);
  end;
  
  varname = evalin('base','inputdlg({''Please specify the name of the coordinate matrix variable in the main Matlab workspace which you want to import. This has to be a matrix with three columns, representing X,Y,Z coordinates, or a matrix with four columns, representing X,Y,Z, and zoom level:''},''VastTools - Add Coordinates From Matlab Variable'',1,{''''});');
  if (min(size(varname))==0)
    %'Cancel' pressed
    return;
  end;
  varname = varname{1};
  
  %evalin('base','global vdata; vdata.data.copy2.mtx=icb; clear vdata;');
  try
    mtx = evalin('base', varname);
  catch me
    warndlg(['Variable "' varname '" not found.'],'Error Importing Coordinate Matrix');
    return;
  end;
  
  if ((size(size(mtx),2)~=2)||((size(mtx,2)~=3)&&(size(mtx,2)~=4)))
    warndlg(['Variable "' varname '" is not a 2D matrix with three or four columns.'],'Error Importing Coordinate Matrix');
    return;
  end;
  
%   copy.nroftargets = vdata.data.tl(instance).nroftargets+1;
%   copy.coords = [vdata.data.tl(instance).coords(1:ins,:); double([tcoords zoom]); vdata.data.tl(instance).coords(ins+1:end,:)];
%   copy.name = [vdata.data.tl(instance).name(1:ins) sprintf('Target %d',vdata.data.tl(instance).nroftargets) vdata.data.tl(instance).name(ins+1:end)];
%   copy.segmentnr = [vdata.data.tl(instance).segmentnr(1:ins); selectedsegmentnr; vdata.data.tl(instance).segmentnr(ins+1:end)];
%   copy.properties = [vdata.data.tl(instance).properties(1:ins), ' ', vdata.data.tl(instance).properties(ins+1:end)];
%   copy.notes = [vdata.data.tl(instance).notes(1:ins), ' ', vdata.data.tl(instance).notes(ins+1:end)];
%   copy.comments = [vdata.data.tl(instance).comments(1:ins), ' ', vdata.data.tl(instance).comments(ins+1:end)];

  nroftargets=size(mtx,1);
  
  copy.nroftargets=nroftargets;
  if (size(mtx,2)==3)
    copy.coords=[mtx ones(nroftargets,1)];
  else
    copy.coords=mtx;
  end;
  copy.name=cell(nroftargets,1); copy.name(:) = {''};
  copy.segmentnr=zeros(nroftargets,1);
  copy.properties=cell(nroftargets,1); copy.properties(:) = {''};
  copy.notes=cell(nroftargets,1); copy.notes(:) = {''};
  copy.comments=cell(nroftargets,1); copy.comments(:) = {''};
  
  vdata.data.tl(instance).nroftargets = vdata.data.tl(instance).nroftargets+copy.nroftargets;
  vdata.data.tl(instance).coords = [vdata.data.tl(instance).coords(1:ins,:); copy.coords; vdata.data.tl(instance).coords(ins+1:end,:)];
  vdata.data.tl(instance).name = [vdata.data.tl(instance).name(1:ins); copy.name; vdata.data.tl(instance).name(ins+1:end)];
  vdata.data.tl(instance).segmentnr = [vdata.data.tl(instance).segmentnr(1:ins); copy.segmentnr; vdata.data.tl(instance).segmentnr(ins+1:end)];
  vdata.data.tl(instance).properties = [vdata.data.tl(instance).properties(1:ins); copy.properties; vdata.data.tl(instance).properties(ins+1:end)];
  vdata.data.tl(instance).notes = [vdata.data.tl(instance).notes(1:ins); copy.notes; vdata.data.tl(instance).notes(ins+1:end)];
  vdata.data.tl(instance).comments = [vdata.data.tl(instance).comments(1:ins); copy.comments; vdata.data.tl(instance).comments(ins+1:end)];
  
  vdata.data.tl(instance).ischanged=1;
  tl_updatetable(instance);
  
  
function [] = callback_tlcutselectedrows(varargin)
  global vdata;
  instance=varargin{3};
  
  selected=vdata.data.tl(instance).selected;

  if (min(size(selected))>0)
    cutlist=unique(selected(:,1));
    
    vdata.data.copy.nroftargets=size(cutlist,1);
    vdata.data.copy.coords=vdata.data.tl(instance).coords(cutlist,:);
    vdata.data.copy.name=vdata.data.tl(instance).name(cutlist);
    vdata.data.copy.segmentnr=vdata.data.tl(instance).segmentnr(cutlist);
    vdata.data.copy.properties=vdata.data.tl(instance).properties(cutlist);
    vdata.data.copy.notes=vdata.data.tl(instance).notes(cutlist);
    vdata.data.copy.comments=vdata.data.tl(instance).comments(cutlist);
    
    vdata.data.tl(instance).nroftargets = vdata.data.tl(instance).nroftargets-size(cutlist,1);
    vdata.data.tl(instance).coords(cutlist,:)=[];
    vdata.data.tl(instance).name(cutlist)=[];
    vdata.data.tl(instance).segmentnr(cutlist)=[];
    vdata.data.tl(instance).properties(cutlist)=[];
    vdata.data.tl(instance).notes(cutlist)=[];
    vdata.data.tl(instance).comments(cutlist)=[];
    
    vdata.data.tl(instance).ischanged=1;
    tl_updatetable(instance);
  end;

  
function [] = callback_tlcopyselectedrows(varargin)
  global vdata;
  instance=varargin{3};
  
  selected=vdata.data.tl(instance).selected;
  if (min(size(selected))>0)
    copylist=unique(selected(:,1));
    
    vdata.data.copy.nroftargets=size(copylist,1);
    vdata.data.copy.coords=vdata.data.tl(instance).coords(copylist,:);
    vdata.data.copy.name=vdata.data.tl(instance).name(copylist);
    vdata.data.copy.segmentnr=vdata.data.tl(instance).segmentnr(copylist);
    vdata.data.copy.properties=vdata.data.tl(instance).properties(copylist);
    vdata.data.copy.notes=vdata.data.tl(instance).notes(copylist);
    vdata.data.copy.comments=vdata.data.tl(instance).comments(copylist);
  end;
  
  
function [] = callback_tlpasteselectedrows(varargin)
  global vdata;
  instance=varargin{3};
  
  if (~isfield(vdata.data,'copy'))
    return; %copy buffer is empty
  end;
  
  selected=vdata.data.tl(instance).selected;
  ins=0;
  if (min(size(selected))>0)
    ins=selected(end,1);
  end;
  
  vdata.data.tl(instance).nroftargets = vdata.data.tl(instance).nroftargets+vdata.data.copy.nroftargets;
  vdata.data.tl(instance).coords = [vdata.data.tl(instance).coords(1:ins,:); vdata.data.copy.coords; vdata.data.tl(instance).coords(ins+1:end,:)];
  vdata.data.tl(instance).name = [vdata.data.tl(instance).name(1:ins); vdata.data.copy.name; vdata.data.tl(instance).name(ins+1:end)];
  vdata.data.tl(instance).segmentnr = [vdata.data.tl(instance).segmentnr(1:ins); vdata.data.copy.segmentnr; vdata.data.tl(instance).segmentnr(ins+1:end)];
  vdata.data.tl(instance).properties = [vdata.data.tl(instance).properties(1:ins); vdata.data.copy.properties; vdata.data.tl(instance).properties(ins+1:end)];
  vdata.data.tl(instance).notes = [vdata.data.tl(instance).notes(1:ins); vdata.data.copy.notes; vdata.data.tl(instance).notes(ins+1:end)];
  vdata.data.tl(instance).comments = [vdata.data.tl(instance).comments(1:ins); vdata.data.copy.comments; vdata.data.tl(instance).comments(ins+1:end)];
  
  vdata.data.tl(instance).ischanged=1;
  tl_updatetable(instance);
  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Simple Navigator Functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
function [] = callback_newsimplenavigator(varargin)
  global vdata;
  
  if (~isfield(vdata.data,'exportproj'))
    warndlg('Please render a projection image first, using Export / Export Projection Image.','Error generating Simple Navigator Window');
    return;
  end;
  
  if (~isfield(vdata.data.exportproj,'lastimage'))
    warndlg('Please render a projection image first, using Export / Export Projection Image.','Error generating Simple Navigator Window');
    return;
  end;
  
  vdata.data.nrofsimplenavigators=vdata.data.nrofsimplenavigators+1;
  simplenavigatorwindow(vdata.data.nrofsimplenavigators,[]);
  
  
function [] = callback_loadsimplenavigator(varargin)
  global vdata;
  
  [filename, pathname] = uigetfile({'*.mat';'*.*'},'Select simple navigator image file to open...');
  if (filename==0)
    %'Cancel' was pressed. Don't load.
    return;
  end;
  
  vdata.data.nrofsimplenavigators=vdata.data.nrofsimplenavigators+1;
  simplenavigatorwindow(vdata.data.nrofsimplenavigators,[pathname filename]);  
  
  
function [] = simplenavigatorwindow(instance, inputfilename)
  global vdata;

  %Check if the simple navigator image is loaded from a file and the file contains the correct data
  if (min(size(inputfilename))>0)
    vars = whos('-file',inputfilename);
    if (ismember('sndata', {vars.name})==0)
      warndlg(['ERROR: The file "' inputfilename '" is not a VastTools Simple Navigator Image file.'],'Error loading Simple Navigator Image');
      return;
    end;
  end;
  
  scrsz = get(0,'ScreenSize');
  vdata.data.sn(instance).fh = figure('units','pixels','outerposition',[300 scrsz(4)-639-300 640 640+28],...
    'menubar','none','numbertitle','off','resize','on','name','Simple Navigator Window');
  set(vdata.data.sn(instance).fh,'CloseRequestFcn',{@callback_snquit, instance});
  set(vdata.data.sn(instance).fh,'ResizeFcn',{@callback_snresize, instance});
  vdata.data.sn(instance).open=1;
  
  vdata.data.sn(instance).menu.file = uimenu(vdata.data.sn(instance).fh,'Label','File');
  vdata.data.sn(instance).menu.savetargetlist = uimenu(vdata.data.sn(instance).menu.file,'Label','Save Simple Navigator Image ...','Callback',{@callback_snsave, instance});
  vdata.data.sn(instance).menu.close = uimenu(vdata.data.sn(instance).menu.file,'Label','Close Simple Navigator Window','Callback',{@callback_snquit, instance});
  
  if (min(size(inputfilename))>0)
    load(inputfilename,'sndata');
    vdata.data.sn(instance).data=sndata;
    clear sndata;
    set(vdata.data.sn(instance).fh,'name',['Simple Navigator Image ' inputfilename]);
  else
    vdata.data.sn(instance).data=vdata.data.exportproj.lastimage;
    set(vdata.data.sn(instance).fh,'name',['New Simple Navigator Image']);
  end;
  
  vdata.data.sn(instance).ui.ax = axes('units','pixels', 'position',[20 668-512-105-28 512 512]);
  vdata.data.sn(instance).ui.XLM = get(vdata.data.sn(instance).ui.ax,'xlim');
  vdata.data.sn(instance).ui.YLM = get(vdata.data.sn(instance).ui.ax,'ylim');
  vdata.data.sn(instance).ui.AXP = get(vdata.data.sn(instance).ui.ax,'pos');
  vdata.data.sn(instance).ui.DFX = diff(vdata.data.sn(instance).ui.XLM);
  vdata.data.sn(instance).ui.DFY = diff(vdata.data.sn(instance).ui.YLM);
  
  vdata.data.sn(instance).ui.R = image(vdata.data.sn(instance).data.image/255,'Parent',vdata.data.sn(instance).ui.ax);
  set(vdata.data.sn(instance).ui.ax,'xtick',[],'ytick',[])  % Get rid of ticks.
  
  set(vdata.data.sn(instance).fh,'windowbuttonmotionfcn',{@callback_simplenavmousemove, instance}); % Set the motion detector.
  set(vdata.data.sn(instance).ui.R,'buttondownfcn',{@callback_simplenavimageclick, instance}); %Set the button press callback
  
  %%%% Toolbar
  icons=imread('vttoolicons.png');
  ht = uitoolbar(vdata.data.sn(instance).fh);
  icon=icons(:,1:19,:);
  vdata.data.sn(instance).ui.toolbar_pointer = uitoggletool(ht,'CData',icon,'TooltipString','Goto','Separator','on','OnCallback',{@callback_sntoolbar_pointer_on, instance},'OffCallback',{@callback_sntoolbar_pointer_off, instance},'state','on');
  icon=icons(:,21:39,:);
  vdata.data.sn(instance).ui.toolbar_zoom = uitoggletool(ht,'CData',icon,'TooltipString','Zoom','OnCallback',{@callback_sntoolbar_zoom_on, instance},'OffCallback',{@callback_sntoolbar_zoom_off, instance});
  icon=icons(:,41:59,:);
  vdata.data.sn(instance).ui.toolbar_pan = uitoggletool(ht,'CData',icon,'TooltipString','Pan','OnCallback',{@callback_sntoolbar_pan_on, instance},'OffCallback',{@callback_sntoolbar_pan_off, instance});
  vdata.data.sn(instance).state.actionmode=0;
  vdata.data.sn(instance).filename=inputfilename;


function callback_sntoolbar_pointer_on(varargin)
  global vdata;
  instance=varargin{3};
  
  if (vdata.data.sn(instance).state.actionmode==1)
    vdata.data.sn(instance).state.actionmode=0;
    set(vdata.data.sn(instance).ui.toolbar_zoom,'State','off');
  end;
  if (vdata.data.sn(instance).state.actionmode==2)
    vdata.data.sn(instance).state.actionmode=0;
    set(vdata.data.sn(instance).ui.toolbar_pan,'State','off');
  end;
  set(0, 'currentfigure', vdata.data.sn(instance).fh);
  
function callback_sntoolbar_pointer_off(varargin)
  global vdata;
  instance=varargin{3};
  
  if (vdata.data.sn(instance).state.actionmode==0) %only if switching off pointer mode
    vdata.data.sn(instance).state.actionmode=0;
    set(vdata.data.sn(instance).ui.toolbar_pointer,'State','on'); %switch back on immediately
  end;
  set(0, 'currentfigure', vdata.data.sn(instance).fh);
  
function callback_sntoolbar_zoom_on(varargin)
  global vdata;
  instance=varargin{3};
  
  if (vdata.data.sn(instance).state.actionmode==0)
    vdata.data.sn(instance).state.actionmode=1;
    set(vdata.data.sn(instance).ui.toolbar_pointer,'State','off');
  end;
  if (vdata.data.sn(instance).state.actionmode==2)
    vdata.data.sn(instance).state.actionmode=1;
    set(vdata.data.sn(instance).ui.toolbar_pan,'State','off');
  end;
  
  set(0, 'currentfigure', vdata.data.sn(instance).fh);
  zoom on;
  h=zoom(vdata.data.sn(instance).fh);
  %set(h,'Motion','horizontal');
  %linkaxes(mndata.ui.ax,'xy'); %does not work?
  %vdata.data.sn(instance).oldactionpostcallback=get(h,'ActionPostCallback');
  set(h,'ActionPostCallback', {@callback_zoom_end, instance});
  
function callback_sntoolbar_zoom_off(varargin)
  global vdata;
  instance=varargin{3};
  
  if (vdata.data.sn(instance).state.actionmode==1) %only if switching off zoom mode
    vdata.data.sn(instance).state.actionmode=0;
    set(vdata.data.sn(instance).ui.toolbar_pointer,'State','on');
  end;
  set(0, 'currentfigure', vdata.data.sn(instance).fh);
  zoom off;
  %set(event_obj,'ActionPostCallback',vdata.data.sn(instance).oldactionpostcallback);
  
function callback_zoom_end(varargin)
  % OBJ         handle to the figure that has been clicked on.
  % EVENT_OBJ   handle to event object. The object has the same properties as the EVENT_OBJ of the 'ModePreCallback' callback.
  global vdata;
  instance=varargin{3};
  obj=varargin{1};
  event_obj=varargin{2};
  %set(event_obj,'ActionPostCallback', []);
  %set(event_obj,'ActionPostCallback',vdata.data.sn(instance).oldactionpostcallback);
  
function callback_sntoolbar_pan_on(varargin)
  global vdata;
  instance=varargin{3};
  
  if (vdata.data.sn(instance).state.actionmode==0)
    vdata.data.sn(instance).state.actionmode=2;
    set(vdata.data.sn(instance).ui.toolbar_pointer,'State','off');
  end;
  if (vdata.data.sn(instance).state.actionmode==1)
    vdata.data.sn(instance).state.actionmode=2;
    set(vdata.data.sn(instance).ui.toolbar_zoom,'State','off');
  end;
  
  set(0, 'currentfigure', vdata.data.sn(instance).fh);
  pan on;
  
function callback_sntoolbar_pan_off(varargin)
  global vdata;
  instance=varargin{3};
  
  if (vdata.data.sn(instance).state.actionmode==2) %only if switching off pan mode
    vdata.data.sn(instance).state.actionmode=0;
    set(vdata.data.sn(instance).ui.toolbar_pointer,'State','on');
  end;
  set(0, 'currentfigure', vdata.data.sn(instance).fh);
  pan off;
  
  
function [] = callback_snsave(varargin)
  %Save a simple navigator image to a file
  global vdata;
  instance=varargin{3};
  
  if (min(size(vdata.data.sn(instance).filename>0)))
    targetname=[vdata.data.sn(instance).filename];
  else
    targetname=['simplenavigatorimage.mat'];
  end;
  [filename, pathname] = uiputfile({'*.mat';'*.*'},'Select simple navigator image file to save...',targetname);
  if (filename==0)
    %'Cancel' was pressed. Don't save.
    return;
  end;
  
  sndata=vdata.data.sn(instance).data;

  save([pathname filename],'sndata');
  vdata.data.sn(instance).filename=[pathname filename];
  set(vdata.data.sn(instance).fh,'name',['Simple Navigator Image ' vdata.data.sn(instance).filename]);
  
  
function [] = callback_snquit(varargin)
  global vdata;
  instance=varargin{3};
  
  res = questdlg('Close this simple navigator window?','Close Simple Navigator Window','Yes','No','Yes');
  if strcmp(res,'No') 
    return; 
  end
  
  %%%% CLEANUP
  if ishandle(vdata.data.sn(instance).fh) 
    delete(vdata.data.sn(instance).fh); 
  end
  vdata.data.sn(instance).open=0;
  vdata.data.sn(instance).fh=[];
  
  
function [] = callback_snresize(varargin)
  global vdata;
  instance=varargin{3};
  
  set(vdata.data.sn(instance).fh,'Units','pixels');
  pos = get(vdata.data.sn(instance).fh,'OuterPosition');
  set(vdata.data.sn(instance).ui.ax,'position',[15 15 pos(3)-43 pos(4)-116]);
  axis(vdata.data.sn(instance).ui.ax,'equal');


function [] = callback_simplenavmousemove(varargin)
  global vdata;
  instance=varargin{3};
  
  p = get(vdata.data.sn(instance).ui.ax, 'currentpoint');
  if ((p(1)>=0) && (p(1)<size(vdata.data.sn(instance).data.image,1)) && (p(3)>=0) && (p(3)<size(vdata.data.sn(instance).data.image,2)))
    %Compute XYZ coordinates from image coordinates
  end;
  
function [] = callback_simplenavimageclick(varargin)
  global vdata;
  instance=varargin{3};
  
  if (~checkconnection()) return; end;
  
  p = get(vdata.data.sn(instance).ui.ax, 'currentpoint');
  px=p(1,1)-0.5;
  py=p(1,2)-0.5;
  if ((px>=0) && (px<size(vdata.data.sn(instance).data.image,2)) && (py>=0) && (py<size(vdata.data.sn(instance).data.image,1)))
    %Compute image coordinates
    sx=floor(px);
    sy=floor(py);
    sz=vdata.data.sn(instance).data.zmap(sy+1,sx+1);
    sy=floor(py/vdata.data.sn(instance).data.stretchz);
    %Compute VAST coordinates from image coordinates
    sv=[sx sy sz 1]';
    tv=vdata.data.sn(instance).data.projectback*sv;
    if (tv(3)>vdata.data.sn(instance).data.region.zmax) tv(3)=vdata.data.sn(instance).data.region.zmax; end; %to correct rounding during z stretching
    vdata.vast.setviewcoordinates(tv(1),tv(2),tv(3));
  end;
  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Helper Functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
  
function ret=getchildtreeids(data,parentlist)
  %Uses the 24-column-data matrix as analyzed from VAST color files
  %Gets a list of the IDs of the segment's children's tree (if it exists)

  ret=[];
  pal=parentlist(:);
  for p=1:1:size(pal,1)
    index=parentlist(p);
    if (data(index,15)>0)
      i=data(index,15);
      ret=[ret i getchildtreeids(data,i)]; %Add size of child tree
      while (data(i,17)>0) %add sizes of all nexts
        i=data(i,17);
        ret=[ret i getchildtreeids(data,i)];
      end;
    end;
  end;
  
function ret=checkconnection()
  global vdata;
  ret=0;
  if (vdata.state.isconnected==0)
    warndlg('ERROR: Not connected to VAST. please connect before using this function.','Not connected to VAST');
    return;
  end;
  
  lasterr('');
  try
    vinfo=vdata.vast.getinfo();
  catch
    if (findstr(lasterr,'socket write error'))
      warndlg('ERROR: Connection to VAST lost. Please reconnect.','Error with remote connection to VAST');
      return;
    else
      warndlg(lasterr,'Error with remote connection to VAST');
      return;
    end;
  end;
  if (min(size(vinfo)==0))
    warndlg('ERROR: Requesting data from VAST failed.','Error with remote connection to VAST');
    return;
  end;
  ret=1;