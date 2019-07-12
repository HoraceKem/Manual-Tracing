classdef VASTControlClass < handle
  
  %%%% BY DANIEL BERGER FOR HARVARD-LICHTMAN
  %%%% VERSION: May 30, 2018 - for VAST Lite 1.2
  
  properties
    jtcpobj;
    jtcphelperclasspath;
    isconnected=0;
    
    inres=[];
    nrinints=0;
    inintdata=[];
    nrinuints=0;
    inuintdata=[];
    nrindoubles=0;
    indoubledata=[];
    nrinchars=0;
    inchardata=[];
    nrintext=0;
    intextdata={};
    
    parseheaderok=0;
    parseheaderlen=0;
    lasterror=0;
    thisversionnr=3;
    
    %islittleendian;
    indata=[];
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% CONSTANTS

    GETINFO = 1;
    GETNUMBEROFSEGMENTS = 2;
    GETSEGMENTDATA     = 3;
    GETSEGMENTNAME     = 4;
    SETANCHORPOINT     = 5;
    SETSEGMENTNAME     = 6;
    SETSEGMENTCOLOR    = 7;
    GETVIEWCOORDINATES = 8;
    GETVIEWZOOM        = 9;
    SETVIEWCOORDINATES = 10;
    SETVIEWZOOM        = 11;
    GETNROFLAYERS      = 12;
    GETLAYERINFO       = 13;
    GETALLSEGMENTDATA  = 14;
    GETALLSEGMENTNAMES = 15;
    SETSELECTEDSEGMENTNR = 16;
    GETSELECTEDSEGMENTNR = 17;
    SETSELECTEDLAYERNR = 18;
    GETSELECTEDLAYERNR = 19;
    GETSEGIMAGERAW     = 20;
    GETSEGIMAGERLE     = 21;
    GETSEGIMAGESURFRLE = 22;
    SETSEGTRANSLATION  = 23;
    GETEMIMAGERAW      = 30;
    GETSCREENSHOTIMAGERAW = 40;
    SETSEGIMAGERAW     = 50;
    SETSEGIMAGERLE     = 51;
    SETSEGMENTBBOX     = 60;
    GETFIRSTSEGMENTNR  = 61;
    GETHARDWAREINFO    = 62;
    ADDSEGMENT         = 63;
    MOVESEGMENT        = 64;
    GETAPIVERSION      = 100;
  end
    
  methods
    
    function obj=VASTControlClass()
      %Check for endianness of this computer
      %obj.islittleendian=0;
      %x=1; y=typecast(x,'uint8'); %[0 0 0 0 0 0 240 63] on little-endian
      %if (y(8)==63) obj.islittleendian=1; end;
      %javaaddpath(pwd);
      mp=mfilename('fullpath');
      m=mfilename;
      mpp=mp(1:end-size(m,2));
      javaaddpath(mpp);
      obj.jtcphelperclasspath=mpp;
    end;
    
    function res=connect(obj,host,port,timeout)
      obj.jtcpobj=jtcp('request',host,port,'timeout',timeout,'serialize',false);
      if isfield(obj.jtcpobj,'error')
        res=0;
        return;
      end;
      res=1; %If the request fails, a Java Error will stop the script, so there is no error if this line is reached (original version)
    end;
    
    function res=disconnect(obj)
      jtcp('close',obj.jtcpobj);
      res=1; %If the request fails, a Java Error will stop the script, so there is no error if this line is reached
    end;
    
    function res=getlasterror(obj)
      res=obj.lasterror;
    end;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % GETINFO
    
    function [info, res] = getinfo(obj)
      obj.sendmessage(obj.GETINFO,[]);
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
      if (res==1)
        if ((obj.nrinuints==7)&&(obj.nrindoubles==3)&&(obj.nrinints==3))
          info.datasizex=obj.inuintdata(1);
          info.datasizey=obj.inuintdata(2);
          info.datasizez=obj.inuintdata(3);
          info.voxelsizex=obj.indoubledata(1);
          info.voxelsizey=obj.indoubledata(2);
          info.voxelsizez=obj.indoubledata(3);
          info.cubesizex=obj.inuintdata(4);
          info.cubesizey=obj.inuintdata(5);
          info.cubesizez=obj.inuintdata(6);
          info.currentviewx=obj.inintdata(1);
          info.currentviewy=obj.inintdata(2);
          info.currentviewz=obj.inintdata(3);
          info.nrofmiplevels=obj.inuintdata(7);
        else
          info = [];
          res=0;
          obj.lasterror=2; %unexpected data
        end;
      else
        info=[];
      end;
    end;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % 2: getnumberofsegments();
    function [nr, res] = getnumberofsegments(obj)
      obj.sendmessage(obj.GETNUMBEROFSEGMENTS,[]);
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
      if (res==1)
        if (obj.nrinuints==1)
          nr=obj.inuintdata(1);
        else
          nr = [];
          res=0;
          obj.lasterror=2; %unexpected data
        end;
      else
        nr=0;
      end;
    end;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % 3: //data=getsegmentdata(id);
    function [data, res] = getsegmentdata(obj, id)
      obj.sendmessage(obj.GETSEGMENTDATA,obj.bytesfromuint32(id));
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
      if (res==1)
        if (obj.nrinints==9)&&(obj.nrinuints==9)
          %Columns: Nr  flags  red1 green1 blue1 pattern1  red2 green2 blue2 pattern2  anchorx anchory anchorz  parentnr childnr prevnr nextnr   collapsednr   bboxx1 bboxy1 bboxz1 bboxx2 bboxy2 bboxz2   "name"
          data.id=obj.inuintdata(1); %typecast(obj.inintdata(1),'uint32');
          data.flags=obj.inuintdata(2); %typecast(obj.inintdata(2),'uint32');
          data.col1=obj.inuintdata(3); %typecast(obj.inintdata(3),'uint32');
          data.col2=obj.inuintdata(4); %typecast(obj.inintdata(4),'uint32');
          data.anchorpoint=obj.inintdata(1:3);
          data.hierarchy=obj.inuintdata(5:8); %typecast(obj.inintdata(8:11),'uint32');
          data.collapsednr=obj.inuintdata(9); %typecast(obj.inintdata(12),'uint32');
          data.boundingbox=obj.inintdata(4:9);
        else
          data = [];
          res=0;
          obj.lasterror=2; %unexpected data received
        end;
      else
        data=[];
      end;
    end;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % 4: getsegmentname(id)
    function [name, res] = getsegmentname(obj, id)

      obj.sendmessage(obj.GETSEGMENTNAME,obj.bytesfromuint32(id));
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
      if (res==1)
        if (obj.inres==1)
          name = char(obj.inchardata);
        else
          name = [];
          res=0;
          obj.lasterror=2; %unexpected data received
        end;
      else
        name=[];
      end;
    end;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % 5: setanchorpoint(id, x, y, z)
    function res = setanchorpoint(obj, id, x, y, z)
      obj.sendmessage(obj.SETANCHORPOINT,obj.bytesfromuint32([id x y z]));
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
    end;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % 6: setsegmentname(id, name)
    function res = setsegmentname(obj, id, name)
      obj.sendmessage(obj.SETSEGMENTNAME,[obj.bytesfromuint32(id) obj.bytesfromtext(name)]);
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
    end;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % 7: setsegmentcolor(id, r1,g1,b1,p1,r2,g2,b2,p2)
    function res = setsegmentcolor8(obj, id, r1,g1,b1,p1,r2,g2,b2,p2)
      %r1,g1,b1 is the primary color, r2,g2,b2 is the secondary color (all values 8bit 0..255). p1 is the pattern (0..16 allowed)
      
      v1=uint32(0);
      v2=v1;
      ir1=uint32(r1); ir2=uint32(r2);
      ig1=uint32(g1); ig2=uint32(g2);
      ib1=uint32(b1); ib2=uint32(b2);
      ip1=uint32(p1); ip2=uint32(p2);
      
      v1=v1+bitand(ip1,255)+bitshift(bitand(ib1,255),8)+bitshift(bitand(ig1,255),16)+bitshift(bitand(ir1,255),24);
      v2=v2+bitand(ip2,255)+bitshift(bitand(ib2,255),8)+bitshift(bitand(ig2,255),16)+bitshift(bitand(ir2,255),24);
      obj.sendmessage(obj.SETSEGMENTCOLOR,obj.bytesfromuint32([id v1 v2]));
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
    end;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function res = setsegmentcolor32(obj, id, col1, col2)
      %col1 is the primary color, col2 is the secondary color (all values 32 bit).
      
      obj.sendmessage(obj.SETSEGMENTCOLOR,obj.bytesfromuint32([id uint32(col1) uint32(col2)]));
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
    end;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % GETVIEWCOORDINATES = 8;
    function [x,y,z, res] = getviewcoordinates(obj)
      %all coordinates in pixels at mip0

      obj.sendmessage(obj.GETVIEWCOORDINATES,[]);
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
      if (res==1)
        if (obj.nrinints==3)
          x=obj.inintdata(1);
          y=obj.inintdata(2);
          z=obj.inintdata(3);        
        else
          x=0; y=0; z=0;
          res=0;
          obj.lasterror=2; %unexpected data received
        end;
      else
        x=0; y=0; z=0;
      end;
    end;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % GETVIEWZOOM        = 9;
    function [zoom, res] = getviewzoom(obj)
      %all coordinates in pixels at mip0

      obj.sendmessage(obj.GETVIEWZOOM,[]);
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
      if (res==1)
        if (obj.nrinints==1)
          zoom=obj.inintdata(1);
        else
          zoom=0;
          res=0;
          obj.lasterror=2; %unexpected data received
        end;
      else
        zoom=0;
      end;
    end;
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % SETVIEWCOORDINATES = 10;
    function res = setviewcoordinates(obj, x, y, z)
      %all coordinates in pixels at mip0

      obj.sendmessage(obj.SETVIEWCOORDINATES,obj.bytesfromuint32([uint32(x) uint32(y) uint32(z)]));
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
    end;
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % SETVIEWZOOM        = 11;
    function res = setviewzoom(obj, zoom)
    %all coordinates in pixels at mip0

      obj.sendmessage(obj.SETVIEWZOOM,obj.bytesfromint32(int32(zoom)));
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
    end;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % GETNROFLAYERS = 12;
    function [nroflayers, res] = getnroflayers(obj)

      obj.sendmessage(obj.GETNROFLAYERS,[]);
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
      if (res==1)
        if (obj.nrinuints==1)
          nroflayers=obj.inuintdata(1);
        else
          nroflayers=0;
          res=0;
          obj.lasterror=2; %unexpected data received
        end;
      else
        nroflayers=0;
      end;
    end;
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % GETLAYERINFO = 13;
    function [layerinfo, res] = getlayerinfo(obj, layernr)

      obj.sendmessage(obj.GETLAYERINFO,obj.bytesfromuint32(uint32(layernr)));
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
      if (res==1)
        if (obj.nrinints==7)&&((obj.nrinuints==1)||(obj.nrinuints==4))&&(obj.nrindoubles==3)
          layerinfo.type=obj.inintdata(1);
          layerinfo.editable=obj.inintdata(2);
          layerinfo.visible=obj.inintdata(3);
          layerinfo.brightness=obj.inintdata(4);
          layerinfo.contrast=obj.inintdata(5);
          layerinfo.opacitylevel=obj.indoubledata(1);
          layerinfo.brightnesslevel=obj.indoubledata(2);
          layerinfo.contrastlevel=obj.indoubledata(3);
          layerinfo.blendmode=obj.inintdata(6);
          layerinfo.blendoradd=obj.inintdata(7);
          layerinfo.tintcolor=obj.inuintdata(1);
          layerinfo.name=obj.inchardata;
          if (obj.nrinuints==4)
            layerinfo.redtargetcolor=obj.inuintdata(2);
            layerinfo.greentargetcolor=obj.inuintdata(3);
            layerinfo.bluetargetcolor=obj.inuintdata(4);
          end;
        else
          layerinfo=[];
          res=0;
          obj.lasterror=2; %unexpected data received
        end;
      else
        layerinfo=[];
      end;
    end;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % GETALLSEGMENTDATA  = 14;
    function [segdata, res] = getallsegmentdata(obj)

      obj.sendmessage(obj.GETALLSEGMENTDATA,[]);
      obj.readdatablockwithhelper();
      indata1=obj.indata;
      parseheader(obj,indata1); %parse header to find out how much data will be sent
      expectedlength=obj.parseheaderlen+12;
      obj.indata=int8(zeros(1,expectedlength));
      writepos=size(indata1,2)+1;
      obj.indata(1:size(indata1,2))=indata1;
      while (writepos<expectedlength)
        indata2=int8(jtcp('read',obj.jtcpobj,'helperClassPath',obj.jtcphelperclasspath));
        obj.indata(writepos:writepos+size(indata2,2)-1)=indata2;
        writepos=writepos+size(indata2,2);
      end;
      
      if (obj.inres==0)
        parse(obj,obj.indata);
      end;
      res=processerror(obj);
      if (res==1)
        uid=typecast(obj.indata(17:end), 'uint32');
        id=typecast(obj.indata(17:end), 'int32');
        sp=2;
        for i=1:1:uid(1)
          segdata{i}.id=i-1;
          segdata{i}.flags=uid(sp);
          segdata{i}.col1=uid(sp+1);
          segdata{i}.col2=uid(sp+2);
          segdata{i}.anchorpoint=id(sp+3:sp+5); % x,y,z
          segdata{i}.hierarchy=uid(sp+6:sp+9); % parent,child,prev,next
          segdata{i}.collapsednr=uid(sp+10);
          segdata{i}.boundingbox=id(sp+11:sp+16); %x1,y1,z1,x2,y2,z2
          
          sp=sp+17;
        end;
      else
        segdata=[];
      end;
    end;
    
    
    function [segdatamatrix, res] = getallsegmentdatamatrix(obj)

      obj.sendmessage(obj.GETALLSEGMENTDATA,[]);
      obj.readdatablockwithhelper();
      indata1=obj.indata;
      parseheader(obj,indata1); %parse header to find out how much data will be sent
      expectedlength=obj.parseheaderlen+12;
      obj.indata=int8(zeros(1,expectedlength));
      writepos=size(indata1,2)+1;
      obj.indata(1:size(indata1,2))=indata1;
      while (writepos<expectedlength)
        indata2=int8(jtcp('read',obj.jtcpobj,'helperClassPath',obj.jtcphelperclasspath));
        obj.indata(writepos:writepos+size(indata2,2)-1)=indata2;
        writepos=writepos+size(indata2,2);
      end;
      
       if (obj.inres==0)
        parse(obj,obj.indata);
      end;
      res=processerror(obj);
      if (res==1)
        uid=typecast(obj.indata(17:end), 'uint32');
        id=typecast(obj.indata(17:end), 'int32');
        %bid=typecast(obj.indata(17:end), 'uint8'); %THIS DOES NOT WORK ??? WRONG RESULTS!
        sp=2;
        
        segdatamatrix=zeros(uid(1),24);
        
        for i=1:1:uid(1)
          segdatamatrix(i,1)=i-1;
          segdatamatrix(i,2)=uid(sp);
          segdatamatrix(i,3)=bitand(bitshift(uid(sp+1),-24),255);
          segdatamatrix(i,4)=bitand(bitshift(uid(sp+1),-16),255);
          segdatamatrix(i,5)=bitand(bitshift(uid(sp+1),-8),255);
          segdatamatrix(i,6)=bitand(uid(sp+1),255);
          segdatamatrix(i,7)=bitand(bitshift(uid(sp+2),-24),255);
          segdatamatrix(i,8)=bitand(bitshift(uid(sp+2),-16),255);
          segdatamatrix(i,9)=bitand(bitshift(uid(sp+2),-8),255);
          segdatamatrix(i,10)=bitand(uid(sp+2),255);
          segdatamatrix(i,11:13)=id(sp+3:sp+5);
          segdatamatrix(i,14:17)=uid(sp+6:sp+9);
          segdatamatrix(i,18)=uid(sp+10);
          segdatamatrix(i,19:24)=id(sp+11:sp+16);
          
          sp=sp+17;
        end;
        segdatamatrix=segdatamatrix(2:end,:);
      else
        segdatamatrix=[];
      end;
    end;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % GETALLSEGMENTNAMES = 15;
    function [segname, res] = getallsegmentnames(obj)
      
      obj.sendmessage(obj.GETALLSEGMENTNAMES,[]);
      obj.readdatablockwithhelper();
      indata1=obj.indata;
      parseheader(obj,indata1); %parse header to find out how much data will be sent
      expectedlength=obj.parseheaderlen+12;
      obj.indata=int8(zeros(1,expectedlength));
      writepos=size(indata1,2)+1;
      obj.indata(1:size(indata1,2))=indata1;
      while (writepos<expectedlength)
        indata2=int8(jtcp('read',obj.jtcpobj,'helperClassPath',obj.jtcphelperclasspath));
        obj.indata(writepos:writepos+size(indata2,2)-1)=indata2;
        writepos=writepos+size(indata2,2);
      end;
      
      if (obj.inres==0)
        parse(obj,obj.indata);
      end;
      res=processerror(obj);
      if (res==1)
        nrnames=typecast(obj.indata(17:20), 'uint32');
        
        sp=20;
        for i=1:1:nrnames
          sq=sp+1;
          while (obj.indata(sq)~=0)
            sq=sq+1;
          end;
          
          bf=obj.indata(sp+1:sq-1);
          segname{i}=char(bf);
          sp=sq;
        end;
      else
        segname=[];
      end;
    end;
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % SETSELECTEDSEGMENTNR = 16;
    function res=setselectedsegmentnr(obj,segmentnr)
      obj.sendmessage(obj.SETSELECTEDSEGMENTNR,obj.bytesfromint32(segmentnr));
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
    end;
      
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % GETSELECTEDSEGMENTNR = 17;
    function [selectedsegmentnr, res]=getselectedsegmentnr(obj)
      
      obj.sendmessage(obj.GETSELECTEDSEGMENTNR,[]);
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
      if (res==1)
        if (obj.nrinuints==1)
          selectedsegmentnr=obj.inuintdata(1);
        else
          selectedsegmentnr=-1;
          res=0;
          obj.lasterror=2; %unexpected data received
        end;
      else
        selectedsegmentnr=-1;
      end;
    end;
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % SETSELECTEDLAYERNR = 18;
    function res=setselectedlayernr(obj,layernr)
      obj.sendmessage(obj.SETSELECTEDLAYERNR,obj.bytesfromint32(layernr));
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
    end;
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % GETSELECTEDLAYERNR  = 19;
    function [selectedlayernr, selectedemlayernr, selectedsegmentlayernr, res]=getselectedlayernr(obj)
      selectedlayernr=-1;
      selectedemlayernr=-1;
      selectedsegmentlayernr=-1;
      obj.sendmessage(obj.GETSELECTEDLAYERNR,[]);
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
      if (res==1)
        if (obj.nrinints==3)
          selectedlayernr=obj.inintdata(1);
          selectedemlayernr=obj.inintdata(2);
          selectedsegmentlayernr=obj.inintdata(3);
        else
          res=0;
          obj.lasterror=2; %unexpected data received
        end;
      end;
    end;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % GETSEGIMAGERAW = 20;
    function [segimage, res] = getsegimageraw(obj, miplevel,minx,maxx,miny,maxy,minz,maxz, flipflag)

      obj.sendmessage(obj.GETSEGIMAGERAW,obj.bytesfromuint32([uint32(miplevel) uint32(minx) uint32(maxx) uint32(miny) uint32(maxy) uint32(minz) uint32(maxz)]));
      obj.readdatablockwithhelper();
      indata1=obj.indata;
      parseheader(obj,indata1); %parse header to find out how much data will be sent
      expectedlength=obj.parseheaderlen+12;
      obj.indata=int8(zeros(1,expectedlength));
      writepos=size(indata1,2)+1;
      obj.indata(1:size(indata1,2))=indata1;
      while (writepos<expectedlength)
        indata2=int8(jtcp('read',obj.jtcpobj,'helperClassPath',obj.jtcphelperclasspath));
        obj.indata(writepos:writepos+size(indata2,2)-1)=indata2;
        writepos=writepos+size(indata2,2);
      end;
      
      if (obj.inres==0)
        parse(obj,obj.indata);
      end;
      res=processerror(obj);
      if (res==1)
        segimage=typecast(obj.indata(17:end), 'uint16');
        if (exist('flipflag','var'))
          if (flipflag==1)
            segimage=permute(segimage,[2 1 3]);
          end;
        end;
      else
        segimage=[];
      end;
    end;

    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % GETSEGIMAGERLE = 21; GETSEGIMAGESURFRLE = 22;
    function [segimageRLE,res] = getsegimageRLE(obj, miplevel,minx,maxx,miny,maxy,minz,maxz,surfonlyflag)

      if (surfonlyflag==0)
        obj.sendmessage(obj.GETSEGIMAGERLE,obj.bytesfromuint32([uint32(miplevel) uint32(minx) uint32(maxx) uint32(miny) uint32(maxy) uint32(minz) uint32(maxz)]));
      else
        obj.sendmessage(obj.GETSEGIMAGESURFRLE,obj.bytesfromuint32([uint32(miplevel) uint32(minx) uint32(maxx) uint32(miny) uint32(maxy) uint32(minz) uint32(maxz)]));
      end;
      obj.readdatablockwithhelper();
      indata1=obj.indata;
      parseheader(obj,indata1); %parse header to find out how much data will be sent
      expectedlength=obj.parseheaderlen+12;
      obj.indata=int8(zeros(1,expectedlength));
      writepos=size(indata1,2)+1;
      obj.indata(1:size(indata1,2))=indata1;
      while (writepos<expectedlength)
        indata2=int8(jtcp('read',obj.jtcpobj,'helperClassPath',obj.jtcphelperclasspath));
        obj.indata(writepos:writepos+size(indata2,2)-1)=indata2;
        writepos=writepos+size(indata2,2);
      end;
      
      if (obj.inres==0)
        parse(obj,obj.indata);
      end;
      res=processerror(obj);
      if (res==1)
        segimageRLE=typecast(obj.indata(17:end), 'uint16');
      else
        segimageRLE=[];
      end;
    end;

    
    function [segimage,res] = getsegimageRLEdecoded(obj, miplevel,minx,maxx,miny,maxy,minz,maxz,surfonlyflag, flipflag)

      [segimageRLE, res] = getsegimageRLE(obj, miplevel,minx,maxx,miny,maxy,minz,maxz,surfonlyflag);
      if (res==0)
        segimage=[];
      else
        %Decode RLE
        segimage=uint16(zeros(maxx-minx+1,maxy-miny+1,maxz-minz+1));
        dp=1;
     
        for sp=1:2:size(segimageRLE,2)
          val=segimageRLE(sp);
          num=segimageRLE(sp+1);
          segimage(dp:dp+uint32(num)-1)=val;
          dp=dp+uint32(num);
        end;
      end;
      
      if (exist('flipflag','var'))
        if (flipflag==1)
          segimage=permute(segimage,[2 1 3]);
        end;
      end;
    end;
    
    
    function [values,numbers,res] = getRLEcountunique(obj, miplevel,minx,maxx,miny,maxy,minz,maxz,surfonlyflag)

      [segimageRLE,res] = getsegimageRLE(obj, miplevel,minx,maxx,miny,maxy,minz,maxz,surfonlyflag);
      if (res==0)
        values=[];
        numbers=[];
      else
        maxsegval=max(segimageRLE(1:2:end));
        na=zeros(maxsegval+1,1);
        %Decode RLE
     
        for sp=1:2:size(segimageRLE,2)
          val=segimageRLE(sp);
          num=segimageRLE(sp+1);
          na(val+1)=na(val+1)+double(num);
        end;
        
% SOMEHOW THIS DOESNT WORK
%         sva=segimageRLE(1:2:end);
%         sna=segimageRLE(2:2:end);
%         na(sva+1)=na(sva+1)+double(sna)';
        
        values=find(na>0);
        numbers=na(values);
        values=values-1;
      end;
    end;
    
    
    function [segimage,values,numbers,res] = getsegimageRLEdecodedcountunique(obj, miplevel,minx,maxx,miny,maxy,minz,maxz,surfonlyflag, flipflag)

      [segimageRLE,res] = getsegimageRLE(obj, miplevel,minx,maxx,miny,maxy,minz,maxz,surfonlyflag);
      if (res==0)
        segimage=[];
        values=[];
        numbers=[];
      else
        maxsegval=max(segimageRLE(1:2:end));
        na=zeros(maxsegval+1,1);
        %Decode RLE
        segimage=uint16(zeros(maxx-minx+1,maxy-miny+1,maxz-minz+1));
        dp=1;
     
        for sp=1:2:size(segimageRLE,2)
          val=segimageRLE(sp);
          num=segimageRLE(sp+1);
          segimage(dp:dp+uint32(num)-1)=val;
          na(val+1)=na(val+1)+double(num);
          dp=dp+uint32(num);
        end;
        
        values=find(na>0);
        numbers=na(values);
        values=values-1;
        
        if (exist('flipflag','var'))
          if (flipflag==1)
            segimage=permute(segimage,[2 1 3]);
          end;
        end;
      end;
    end;
    

    function [segimage,values,numbers,bboxes,res] = getsegimageRLEdecodedbboxes(obj, miplevel,minx,maxx,miny,maxy,minz,maxz,surfonlyflag, flipflag)
      %tic
      [segimageRLE,res] = getsegimageRLE(obj, miplevel,minx,maxx,miny,maxy,minz,maxz,surfonlyflag);
      %disp('image transmitted in:'); toc
      %tic
      if (res==0)
        segimage=[];
        values=[];
        numbers=[];
        bboxes=[];
      else
        maxsegval=max(segimageRLE(1:2:end));
        na=int32(zeros(maxsegval+1,1));
        bboxes=zeros(maxsegval+1,6)-1;
        %Decode RLE
        segimage=uint16(zeros(maxx-minx+1,maxy-miny+1,maxz-minz+1));
        dp=int32(1);
        xs=int32(maxx-minx+1); 
        ys=int32(maxy-miny+1); 
        zs=int32(maxz-minz+1);
        x1=1; y1=1; z1=1;
        for sp=1:2:size(segimageRLE,2)
          val=segimageRLE(sp);
          num=int32(segimageRLE(sp+1));
          dp2=dp+int32(num)-1;
          segimage(dp:dp2)=val;
          na(val+1)=na(val+1)+num;
          
          %%%%%%%%%%%%%% Bounding box computations
          if ((x1+num-1)<=xs)
            xmin=x1;
            xmax=x1+num-1;
            ymin=y1; ymax=y1;
            zmin=z1; zmax=z1;
            
            x1=x1+num; %go to next start
          else
          
            % Uses idivide because the standard division in matlab has the wrong rounding behavior
            z1=idivide(dp-1,xs*ys)+1; %z1=((dp-1)/(xs*ys))+1;
            r=dp-((z1-1)*xs*ys);
            y1=idivide(r-1,xs)+1; %y1=((r-1)/xs)+1;
            x1=r-((y1-1)*xs);
            
            z2=idivide(dp2-1,xs*ys)+1; %z2=((dp2-1)/(xs*ys))+1;
            r=dp2-((z2-1)*xs*ys);
            y2=idivide(r-1,xs)+1; %y2=((r-1)/xs)+1;
            x2=r-((y2-1)*xs);
            
            xmin=min([x1 x2]); xmax=max([x1 x2]);
            ymin=min([y1 y2]); ymax=max([y1 y2]);
            zmin=min([z1 z2]); zmax=max([z1 z2]);
            if (zmax>zmin)
              %we must go over the plane corner, which extends the bbox to max in XY
              xmin=1; xmax=xs;
              ymin=1; ymax=ys;
            end;
            if (ymax>ymin)
              %we must go over the plane edge, which extends the bbox to max in X
              xmin=1; xmax=xs;
            end;
            
            x1=x2+1; %go to next start
            y1=y2;
            z1=z2;
          end;
          
          if (bboxes(val+1,1)==-1)
            bboxes(val+1,:)=[xmin,ymin,zmin,xmax,ymax,zmax];
          else
            
            tbbox=bboxes(val+1,:);
            if (xmin<tbbox(1))
              tbbox(1)=xmin;
            end;
            if (ymin<tbbox(2))
              tbbox(2)=ymin;
            end;
            if (zmin<tbbox(3))
              tbbox(3)=zmin;
            end;
            if (xmax>tbbox(4))
              tbbox(4)=xmax;
            end;
            if (ymax>tbbox(5))
              tbbox(5)=ymax;
            end;
            if (zmax>tbbox(6))
              tbbox(6)=zmax;
            end;
            bboxes(val+1,:)=tbbox;
          end;
          
          dp=dp2+1;
        end;
        
        values=find(na>0);
        numbers=na(values);
        bboxes=bboxes(values,:);
        values=values-1;
        
        if (exist('flipflag','var'))
          if (flipflag==1)
            segimage=permute(segimage,[2 1 3]);
          end;
        end;
      end;
      %disp('  decoded in:');
      %toc
    end;
    
    
    function tbbox=expandboundingbox(obj,bbox1,bbox2)
      %This assumes the following order of coordinates: xmin,ymin,zmin,xmax,ymax,zmax

      tbbox=bbox1;
      if (bbox2(1)<bbox1(1))
        tbbox(1)=bbox2(1);
      end;
      if (bbox2(2)<bbox1(2))
        tbbox(2)=bbox2(2);
      end;
      if (bbox2(3)<bbox1(3))
        tbbox(3)=bbox2(3);
      end;
      if (bbox2(4)>bbox1(4))
        tbbox(4)=bbox2(4);
      end;
      if (bbox2(5)>bbox1(5))
        tbbox(5)=bbox2(5);
      end;
      if (bbox2(6)>bbox1(6))
        tbbox(6)=bbox2(6);
      end;
    end;
    
    function tbboxes=expandboundingboxes(obj,bboxes1,bboxes2)
      %This assumes the following order of coordinates: xmin,ymin,zmin,xmax,ymax,zmax
      %processes many bounding boxes at once
      %uses -1 in bboxes1 as indicator that the initial bounding box is defined by bboxes2
      
      tbboxes=bboxes1;
      for i=1:1:size(bboxes1,1)
        if (bboxes1(i,1)==-1)
          tbboxes(i,:)=bboxes2(i,:);
        else
          if (bboxes2(i,1)<bboxes1(i,1))
            tbboxes(i,1)=bboxes2(i,1);
          end;
          if (bboxes2(i,2)<bboxes1(i,2))
            tbboxes(i,2)=bboxes2(i,2);
          end;
          if (bboxes2(i,3)<bboxes1(i,3))
            tbboxes(i,3)=bboxes2(i,3);
          end;
          if (bboxes2(i,4)>bboxes1(i,4))
            tbboxes(i,4)=bboxes2(i,4);
          end;
          if (bboxes2(i,5)>bboxes1(i,5))
            tbboxes(i,5)=bboxes2(i,5);
          end;
          if (bboxes2(i,6)>bboxes1(i,6))
            tbboxes(i,6)=bboxes2(i,6);
          end;
        end;
      end;
    end;
      

    function res = setsegtranslation(obj, sourcearray, targetarray)
      %sets the segmentation translation for getsegimage functions.
      %sourcearray is an array of segment numbers, targetarray an array of destination segment numbers.
      %before the image is transmitted, all voxels with a value in sourcearray will be translated to the corresponding number
      %in targetarray. segment numbers which do not appear in sourcearray will be set to 0 (background).
      %call with empty arrays to remove segmentation translation.

      if (length(sourcearray(:))~=length(targetarray(:)))
        %sourcearray and targetarray must have the same length.
        res=0;
        obj.lasterror=50;
      else
        translate=uint32(zeros(1,2*length(sourcearray(:))));
        translate(1:2:end)=uint32(sourcearray(:));
        translate(2:2:end)=uint32(targetarray(:));
        obj.sendmessage(obj.SETSEGTRANSLATION,obj.bytesfromdata(translate));
        obj.readdatablock();
        parse(obj,obj.indata);
        res=processerror(obj);
      end;
    end;
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % GETEMIMAGERAW = 30;
    function [emimage,res] = getemimageraw(obj, layernr,miplevel,minx,maxx,miny,maxy,minz,maxz)

      obj.sendmessage(obj.GETEMIMAGERAW,obj.bytesfromuint32([uint32(layernr) uint32(miplevel) uint32(minx) uint32(maxx) uint32(miny) uint32(maxy) uint32(minz) uint32(maxz)]));
      obj.readdatablockwithhelper();
      indata1=obj.indata;
      parseheader(obj,indata1); %parse header to find out how much data will be sent
      expectedlength=obj.parseheaderlen+12;
      obj.indata=int8(zeros(1,expectedlength));
      writepos=size(indata1,2)+1;
      obj.indata(1:size(indata1,2))=indata1;
      while (writepos<expectedlength)
        indata2=int8(jtcp('read',obj.jtcpobj,'helperClassPath',obj.jtcphelperclasspath));
        obj.indata(writepos:writepos+size(indata2,2)-1)=indata2;
        writepos=writepos+size(indata2,2);
      end;
      
      if (obj.inres==0)
        parse(obj,obj.indata);
      end;
      res=processerror(obj);
      if (res==1)
        emimage=typecast(obj.indata(17:end), 'uint8');
      else
        emimage=[];    
      end;
    end;
    
    function [emimage,res] = getemimage(obj, layernr,miplevel,minx,maxx,miny,maxy,minz,maxz)
      [emimageraw,res] = getemimageraw(obj, layernr,miplevel,minx,maxx,miny,maxy,minz,maxz);
      if (res==1)
        if (size(emimageraw,2)==round((maxx-minx+1)*(maxy-miny+1)*(maxz-minz+1)))
          %One byte per pixel
          if (minz==maxz)
            emimage=permute(reshape(emimageraw,int32(maxx-minx+1),int32(maxy-miny+1)),[2 1]);
          else
            emimage=permute(reshape(emimageraw,int32(maxx-minx+1),int32(maxy-miny+1),int32(maxz-minz+1)),[2 1 3]);
          end;
        else
          %Three bytes per pixel
          if (minz==maxz)
            emimage=flipdim(permute(reshape(emimageraw,3,int32(maxx-minx+1),int32(maxy-miny+1)),[3 2 1]),3);
          else
            emimage=flipdim(permute(reshape(emimageraw,3,int32(maxx-minx+1),int32(maxy-miny+1),int32(maxz-minz+1)),[3 2 4 1]),4);
          end;
        end;
      else
        emimage=emimageraw;
      end;
    end;
    
    
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % GETSCREENSHOTIMAGERAW = 40;
    function [screenshotimage,res] = getscreenshotimageraw(obj, miplevel,minx,maxx,miny,maxy,minz,maxz,collapseseg)

      obj.sendmessage(obj.GETSCREENSHOTIMAGERAW,obj.bytesfromuint32([uint32(miplevel) uint32(minx) uint32(maxx) uint32(miny) uint32(maxy) uint32(minz) uint32(maxz) uint32(collapseseg)]));
      obj.readdatablockwithhelper();
      indata1=obj.indata;
      parseheader(obj,indata1); %parse header to find out how much data will be sent
      expectedlength=obj.parseheaderlen+12;
      obj.indata=int8(zeros(1,expectedlength));
      writepos=size(indata1,2)+1;
      obj.indata(1:size(indata1,2))=indata1;
      while (writepos<expectedlength)
        indata2=int8(jtcp('read',obj.jtcpobj,'helperClassPath',obj.jtcphelperclasspath));
        obj.indata(writepos:writepos+size(indata2,2)-1)=indata2;
        writepos=writepos+size(indata2,2);
      end;
      
      if (obj.inres==0)
        parse(obj,obj.indata);
      end;
      res=processerror(obj);
      if (res==1)
        screenshotimage=typecast(obj.indata(17:end), 'uint8');
      else
        screenshotimage=[];    
      end;
    end;
    
    
    function [screenshotimage,res] = getscreenshotimage(obj, miplevel,minx,maxx,miny,maxy,minz,maxz,collapseseg)
      [screenshotimageraw,res] = getscreenshotimageraw(obj, miplevel,minx,maxx,miny,maxy,minz,maxz,collapseseg);
      if (res==1)
        if (minz==maxz)
          screenshotimage=flipdim(permute(reshape(screenshotimageraw,3,int32(maxx-minx+1),int32(maxy-miny+1)),[3 2 1]),3);
        else
          screenshotimage=flipdim(permute(reshape(screenshotimageraw,3,int32(maxx-minx+1),int32(maxy-miny+1),int32(maxz-minz+1)),[3 2 4 1]),4);
        end;
      else
        screenshotimage=screenshotimageraw;
      end;
    end;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % SETSEGIMAGERAW = 50;
    function res = setsegimageraw(obj, miplevel,minx,maxx,miny,maxy,minz,maxz,segimage)

      if ((size(segimage,2)~=int32(maxx-minx+1))||(size(segimage,1)~=int32(maxy-miny+1))||(size(segimage,3)~=int32(maxz-minz+1)))
        %sourcearray and targetarray must have the same length.
        res=0;
        obj.lasterror=13;
      else
        mparams=obj.bytesfromuint32([uint32(miplevel) uint32(minx) uint32(maxx) uint32(miny) uint32(maxy) uint32(minz) uint32(maxz)]);
        segimage=permute(segimage,[2 1 3]);
        mdata=obj.bytesfromdata(typecast(segimage(:), 'uint16'));
        obj.sendmessage(obj.SETSEGIMAGERAW,[mparams mdata]);
        obj.readdatablock();
        parse(obj,obj.indata);
        res=processerror(obj);
      end;
    end;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % SETSEGIMAGERLE = 51;
    function res = setsegimageRLE(obj, miplevel,minx,maxx,miny,maxy,minz,maxz,segimage)
      %Encodes the image data as RLE and sends the encoded data to VAST
      if ((size(segimage,2)~=int32(maxx-minx+1))||(size(segimage,1)~=int32(maxy-miny+1))||(size(segimage,3)~=int32(maxz-minz+1)))
        %sourcearray and targetarray must have the same length.
        res=0;
        obj.lasterror=13;
      else
        mparams=obj.bytesfromuint32([uint32(miplevel) uint32(minx) uint32(maxx) uint32(miny) uint32(maxy) uint32(minz) uint32(maxz)]);
        segimage=permute(segimage,[2 1 3]);
        rledata=zeros(1,length(segimage),'uint16');

        % RLE encode
        rdp=1;
        rsp=1;
        val=segimage(rsp);
        num=1;
        rsp=rsp+1;
        dp=length(segimage(:));
        
        while ((rsp<=dp)&&(rdp<dp-2))
          if ((segimage(rsp)==val)&&(num<65535))
            num=num+1;
          else
            %store val,num pair here
            rledata(rdp)=val;
            rledata(rdp+1)=num;
            rdp=rdp+2;
            
            val=segimage(rsp);
            num=1;
          end;
          rsp=rsp+1;
        end;
        if (rsp==dp+1)
          rledata(rdp)=val;
          rledata(rdp+1)=num;
          rdp=rdp+2;
        end;
        
        %%%%%%
        mdata=obj.bytesfromdata(rledata(1:rdp-1));
        obj.sendmessage(obj.SETSEGIMAGERLE,[mparams mdata]);
        obj.readdatablock();
        parse(obj,obj.indata);
        res=processerror(obj);
      end;
    end;

    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % SETSEGMENTBBOX = 60;
    function res = setsegmentbbox(obj, id, minx,maxx,miny,maxy,minz,maxz)
      obj.sendmessage(obj.SETSEGMENTBBOX,obj.bytesfromint32([id minx maxx miny maxy minz maxz]));
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
    end;
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % GETFIRSTSEGMENTNR  = 61;
    function [firstsegmentnr, res]=getfirstsegmentnr(obj)
      obj.sendmessage(obj.GETFIRSTSEGMENTNR,[]);
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
      if (res==1)
        if (obj.nrinuints==1)
          firstsegmentnr=obj.inuintdata(1);
        else
          firstsegmentnr=-1;
          res=0;
          obj.lasterror=2; %unexpected data received
        end;
      else
        firstsegmentnr=-1;
      end;
    end;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % GETHARDWAREINFO    = 62;
    function [info, res] = gethardwareinfo(obj)
      obj.sendmessage(obj.GETHARDWAREINFO,[]);
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
      if (res==1)
        if ((obj.nrinuints==1)&&(obj.nrindoubles==7)&&(obj.nrinints==0)&&(obj.nrintext==5))
          info.computername=obj.intextdata{1};
          info.processorname=obj.intextdata{2};
          info.processorspeed_ghz=obj.indoubledata(1);
          info.nrofprocessorcores=obj.inuintdata(1);
          info.tickspeedmhz=obj.indoubledata(2);
          info.mmxssecapabilities=obj.intextdata{3};
          info.totalmemorygb=obj.indoubledata(3);
          info.freememorygb=obj.indoubledata(4);
          info.graphicscardname=obj.intextdata{4};
          info.graphicsdedicatedvideomemgb=obj.indoubledata(5);
          info.graphicsdedicatedsysmemgb=obj.indoubledata(6);
          info.graphicssharedsysmemgb=obj.indoubledata(7);
          info.graphicsrasterizerused=obj.intextdata{5};
        else
          info = [];
          res=0;
          obj.lasterror=2; %unexpected data
        end;
      else
        info=[];
      end;
    end;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % ADDSEGMENT = 63;
    function [id, res] = addsegment(obj, refid, nextorchild, name)
      %nextorchild: 0: next, 1: child
      obj.sendmessage(obj.ADDSEGMENT,[obj.bytesfromuint32([refid nextorchild]) obj.bytesfromtext(name)]);
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
      if (res==1)
        if (obj.nrinuints==1)
          id=obj.inuintdata(1);
        else
          id=0;
          res=0;
          obj.lasterror=2; %unexpected data received
        end;
      else
        id=0;
      end;
    end;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % MOVESEGMENT = 64;
    function res = movesegment(obj, id, refid, nextorchild)
      obj.sendmessage(obj.MOVESEGMENT,obj.bytesfromuint32([id refid nextorchild]));
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
    end;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % 100: getapiversion();
    function [version, res] = getapiversion(obj)
      obj.lasterror=0;
      obj.sendmessage(obj.GETAPIVERSION,[]);
      obj.readdatablock();
      parse(obj,obj.indata);
      res=processerror(obj);
      if (res==1)
        if (obj.nrinuints==1)
          version=obj.inuintdata(1);
        else
          version = [];
          res=0;
          obj.lasterror=2; %unexpected data
        end;
      else
        version=[];
      end;
    end;
    
    function [version, res] = getcontrolclassversion(obj)
      %Returns the locally defined version number of this script (VastControlClass.m)
      res=1;
      version=obj.thisversionnr;
    end;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function res = processerror(obj)
      obj.lasterror=0;
      if (obj.inres==0)
        if (obj.nrinuints==1)
          obj.lasterror=obj.inuintdata(1); %get error number sent by Vast
        else
          obj.lasterror=1; %unknown error
        end;
      end;
      res=obj.inres;
    end;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function res=bytesfromint32(obj,value)
      val=int32(value);
      va=typecast(val,'uint8');
      res=[];
      for i=1:4:max(size(va))
        res=[res 4 va(i) va(i+1) va(i+2) va(i+3)];
      end;
    end;
    
    function res=bytesfromuint32(obj,value)
      val=uint32(value);
      va=typecast(val,'uint8');
      res=[];
      for i=1:4:max(size(va))
        res=[res 1 va(i) va(i+1) va(i+2) va(i+3)];
      end;
    end;
    
    function res=bytesfromdouble(obj,value)
      val=double(value(1,1));
      res=typecast(val,'uint8');
%       if (obj.islittleendian==0)
%         ires=res;
%         res=ires(end:-1:1);
%       end;
      res=[2 res];
    end;
    
    function res=bytesfromtext(obj,value)
      val=uint8(value);
      res=[3 val 0];
    end;
    
    function res=bytesfromdata(obj,value)
      val=typecast(value(:),'uint8');
      len=uint32(length(val));
      len=typecast(len,'uint8');
      res=[5 len(1) len(2) len(3) len(4) val'];
    end;
    
    %--------------------------------------------------------------------
    function res=sendmessage(obj,messagenr,message)
      %The VAST Server expects data in the following format:
      %0..3: 'VAST', message header for binary messages
      %4..11: total size of data following; least-significant byte first
      %12..15: message number (uint32)
      %16...: message parameters (uint8!)
      
      len=uint64(max(size(message)))+4;
      len1=uint8(bitand(len,255));
      len2=uint8(bitand(bitshift(len,-8),255));
      len3=uint8(bitand(bitshift(len,-16),255));
      len4=uint8(bitand(bitshift(len,-24),255));
      len5=uint8(bitand(bitshift(len,-32),255));
      len6=uint8(bitand(bitshift(len,-40),255));
      len7=uint8(bitand(bitshift(len,-48),255));
      len8=uint8(bitand(bitshift(len,-56),255));
      mnr=uint32(messagenr);
      mnr1=uint8(bitand(mnr,255));
      mnr2=uint8(bitand(bitshift(mnr,-8),255));
      mnr3=uint8(bitand(bitshift(mnr,-16),255));
      mnr4=uint8(bitand(bitshift(mnr,-24),255));
      msg1=uint8(['VAST' len1 len2 len3 len4 len5 len6 len7 len8 mnr1 mnr2 mnr3 mnr4 message]);
      msg2=typecast(msg1, 'int8'); %necessary for lossless transmission of uint8 data
      jtcp('write',obj.jtcpobj,msg2);
    end;
    
    %--------------------------------------------------------------------
    function res=sendmessagewithhelper(obj,messagenr,message)
      %The VAST Server expects data in the following format:
      %0..3: 'VAST', message header for binary messages
      %4..11: total size of data following; least-significant byte first
      %12..15: message number (uint32)
      %16...: message parameters (uint8!)
      
      len=uint64(max(size(message)))+4;
      len1=uint8(bitand(len,255));
      len2=uint8(bitand(bitshift(len,-8),255));
      len3=uint8(bitand(bitshift(len,-16),255));
      len4=uint8(bitand(bitshift(len,-24),255));
      len5=uint8(bitand(bitshift(len,-32),255));
      len6=uint8(bitand(bitshift(len,-40),255));
      len7=uint8(bitand(bitshift(len,-48),255));
      len8=uint8(bitand(bitshift(len,-56),255));
      mnr=uint32(messagenr);
      mnr1=uint8(bitand(mnr,255));
      mnr2=uint8(bitand(bitshift(mnr,-8),255));
      mnr3=uint8(bitand(bitshift(mnr,-16),255));
      mnr4=uint8(bitand(bitshift(mnr,-24),255));
      msg1=uint8(['VAST' len1 len2 len3 len4 len5 len6 len7 len8 mnr1 mnr2 mnr3 mnr4 message]);
      msg2=typecast(msg1, 'int8'); %necessary for lossless transmission of uint8 data
      jtcp('write',obj.jtcpobj,msg2,'helperClassPath',obj.jtcphelperclasspath);
    end;
    
    %--------------------------------------------------------------------
    function readdatablock(obj)
      obj.indata=[];
      while (min(size(obj.indata))==0)
        obj.indata=jtcp('read',obj.jtcpobj);
        pause(0.01);
      end;
    end;
    
    %--------------------------------------------------------------------
    function readdatablockwithhelper(obj)
      obj.indata=[];
      while (min(size(obj.indata))==0)
        obj.indata=int8(jtcp('read',obj.jtcpobj,'helperClassPath',obj.jtcphelperclasspath));
        pause(0.01);
      end;
    end;
    
    %--------------------------------------------------------------------
    function parseheader(obj,indata)
      obj.parseheaderok=0;
      obj.parseheaderlen=0;
      obj.inres=[];
      if (max(size(indata))<16) 
        return;
      end;
      header=typecast(indata(1:12), 'uint8');
      if ((header(1)~='V')||(header(2)~='A')||(header(3)~='S')||(header(4)~='T')) 
        return;
      end;
      obj.parseheaderok=1;
      obj.parseheaderlen=(uint64(header(5)))+(bitshift(uint64(header(6)),8))+(bitshift(uint64(header(7)),16))+(bitshift(uint64(header(8)),24));
      obj.parseheaderlen=obj.parseheaderlen+(bitshift(uint64(header(9)),32))+(bitshift(uint64(header(10)),40))+(bitshift(uint64(header(11)),48))+(bitshift(uint64(header(12)),56));
      rf=indata(13:16);
      obj.inres = typecast(rf, 'int32');
    end;
    
    %--------------------------------------------------------------------
    function parse(obj,indata)
      obj.nrinints=0;
      obj.inintdata=[];
      obj.nrinuints=0;
      obj.inuintdata=[];
      obj.nrindoubles=0;
      obj.indoubledata=[];
      obj.nrinchars=0;
      obj.inchardata=[];
      obj.nrintext=0;
      obj.intextdata={};
      obj.inres=[];
      if (max(size(indata))<12)
        return;
      end;
      indata=typecast(indata, 'uint8');
      if ((indata(1)~='V')||(indata(2)~='A')||(indata(3)~='S')||(indata(4)~='T'))
        return;
      end;
      len=(uint64(indata(5)))+(bitshift(uint64(indata(6)),8))+(bitshift(uint64(indata(7)),16))+(bitshift(uint64(indata(8)),24));
      len=len+(bitshift(uint64(indata(9)),32))+(bitshift(uint64(indata(10)),40))+(bitshift(uint64(indata(11)),48))+(bitshift(uint64(indata(12)),56));
      if (len~=(max(size(indata))-12))
        return;
      end;
      
      rf=indata(13:16);
      obj.inres = typecast(rf, 'int32');      
      
      p=17;
      
      while (p<size(indata,2))
        switch indata(p)
          case 1 %unsigned int
            obj.nrinuints=obj.nrinuints+1;
            bf=indata(p+1:p+4);
            obj.inuintdata(obj.nrinuints) = typecast(bf, 'uint32');
            p=p+5;
            
          case 2 %double
            obj.nrindoubles=obj.nrindoubles+1;
            bf=indata(p+1:p+8);
            obj.indoubledata(obj.nrindoubles) = typecast(bf, 'double');
            p=p+9;
            
          case 3 %0-terminated text
            q=p+1;
            while ((q<size(indata,2))&&(indata(q)~=0))
              q=q+1;
            end;
            if (indata(q)~=0)
              p=len+4;
            else
              bf=indata(p+1:q-1);
              obj.inchardata=char(bf);
              obj.nrinchars=max(size(bf));
              obj.nrintext=obj.nrintext+1;
              obj.intextdata{obj.nrintext}=char(bf);
              p=q+1;
            end;
            
          case 4 %signed int
            obj.nrinints=obj.nrinints+1;
            bf=indata(p+1:p+4);
            obj.inintdata(obj.nrinints) = typecast(bf, 'int32');
            p=p+5;
            
          otherwise
            p=size(indata,2);
        end;
      end;
      obj.inintdata=int32(obj.inintdata);
      obj.inuintdata=uint32(obj.inuintdata);
    end;
  end;
end