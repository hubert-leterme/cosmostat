pro mkhdr, header, im, naxisx, IMAGE = image, EXTEND = extend
;+
; NAME:
;       MKHDR
; PURPOSE:
;       Make a minimal primary (or IMAGE extension) FITS header
; EXPLANATION:
;       If an array is supplied,  then the created FITS header will be 
;       appropriate to the supplied array.  Otherwise, the user can specify 
;       the dimensions and datatype.
;
; CALLING SEQUENCE:
;       MKHDR, header                   ;Prompt for image size and type
;               or
;       MKHDR, header, im, [ /IMAGE, /EXTEND ]
;               or
;       MKHDR, header, type, naxisx, [/IMAGE, /EXTEND ]         
;
; OPTIONAL INPUTS:
;       IM - If IM is a vector or array then the header will be made
;               appropriate to the size and type of IM.  IM does not have
;               to be the actual data; it can be a dummy array of the same
;               type and size as the data.    Set IM = '' to create a dummy
;               header with NAXIS = 0. 
;       TYPE - If more than 2 parameters are supplied, then the second parameter
;               is intepreted as an integer giving the IDL datatype e.g. 
;               1 - LOGICAL*1, 2 - INTEGER*2, 4 - REAL*4, 3 - INTEGER*4
;       NAXISX - Vector giving the size of each dimension (NAXIS1, NAXIS2, 
;               etc.).  
;
; OUTPUT:
;       HDR - image header, (string array) with required keywords
;               BITPIX, NAXIS, NAXIS1, ... Further keywords can be added
;               to the header with SXADDPAR. 
;
; OPTIONAL INPUT KEYWORDS:
;       IMAGE   = If set, then a minimal header for a FITS IMAGE extension
;               is created.    An IMAGE extension header is identical to
;               a primary FITS header except the first keyword is 
;               'XTENSION' = 'IMAGE' instead of 'SIMPLE  ' = 'T'
;       EXTEND  = If set, then the keyword EXTEND is inserted into the file,
;               with the value of "T" (true).
;
; RESTRICTIONS:
;       (1)  MKHDR should not be used to make an STSDAS header or a FITS
;               ASCII or Binary Table header.   Instead use
;
;               SXHMAKE - to create a minimal STSDAS header
;               FXHMAKE - to create a minimal FITS binary table header
;               FTCREATE - to create a minimal FITS ASCII table header
;
;       (2)  Any data already in the header before calling MKHDR
;               will be destroyed.
; EXAMPLE:
;       Create a minimal FITS header, HDR, for a 30 x 40 x 50 INTEGER*2 array
;
;             IDL> MKHDR, HDR, 2, [30,40,50]
;
;       Alternatively, if the array already exists as an IDL variable, ARRAY,
;
;              IDL> MKHDR, HDR, ARRAY
;
; PROCEDURES CALLED:
;       SXADDPAR, GET_DATE
;
; REVISION HISTORY:
;       Written November, 1988               W. Landsman
;       May, 1990, Adapted for IDL Version 2.0, J. Isensee
;       Aug, 1997, Use SYSTIME(), new DATE format  W. Landsman
;       Converted to IDL V5.0   W. Landsman   September 1997
;       Allow unsigned data types    W. Landsman   December 1999
;       Set BZERO = 0 for unsigned integer data  W. Landsman January 2000
;       EXTEND keyword must immediately follow last NAXISi W. Landsman Sep 2000
;-                          
 On_error,2

 npar = N_params()
 if npar LT 1 then begin
   print,'Syntax:  MKHDR, header, [ im, /IMAGE, /EXTEND ]'
   print,'    or   MKHDR, header, [ type, naxisx, /IMAGE, /EXTEND ]'
   print,'   header - output FITS header to be created'
   return
 endif

 if (npar eq 1) then begin               ;Prompt for keyword values
    read,'Enter number of dimensions (NAXIS): ',naxis
    s = lonarr(naxis+2)
    s[0] = naxis
    if ( naxis GT 0 ) then begin       ;Make sure not a dummy header
    for i = 1,naxis do begin       ;Get dimension of each axis
      keyword = 'NAXIS' + strtrim(i,2)
      read,'Enter size of dimension '+ strtrim(i,2) + ' ('+keyword+'): ',nx
      s[i] = nx                            
    endfor
  endif

  print,'Allowed datatypes are (1) INTEGER*1, (2) INTEGER*2, (4) REAL*4,'
  print,'                     (3) INTEGER*4 or (6) COMPLEX*8'
  read,'Enter datatype: ',stype
  s[s[0] + 1] = stype

 endif else $
     if ( npar EQ 2 ) then s = size(im) $  ;Image array supplied
          else  s = [ N_elements(naxisx),naxisx, im ] ;Keyword values supplied

 stype = s[s[0]+1]              ;Type of data    
        case stype of
        0:      message,'ERROR: Input data array is undefined'
        1:      bitpix = 8  
        2:      bitpix = 16  
        3:      bitpix = 32  
        4:      bitpix = -32 
        5:      bitpix = -64 
        6:      bitpix = 64  
        7:      bitpix = 8
       12:      bitpix = 16
       13:      bitpix = 32
        else:   message,'ERROR: Illegal Image Datatype'
        endcase

 header = strarr(s[0] + 7) + string(' ',format='(a80)')      ;Create empty array
 header[0] = 'END' + string(replicate(32b,77))

 if keyword_set( IMAGE) then $
    sxaddpar, header, 'XTENSION', 'IMAGE   ',' IMAGE extension' $
 else $
    sxaddpar, header, 'SIMPLE', 'T',' Written by IDL:  '+ systime()

 sxaddpar, header, 'BITPIX', bitpix
 sxaddpar, header, 'NAXIS', S[0]        ;# of dimensions

 if ( s[0] GT 0 ) then begin
   for i = 1, s[0] do sxaddpar,header,'NAXIS' + strtrim(i,2),s[i]
 endif

 if keyword_set( IMAGE) then begin
     sxaddpar, header, 'PCOUNT', 0, ' No Group Parameters'
     sxaddpar, header, 'GCOUNT', 1, ' One Data Group'
 endif else begin
     if keyword_set( EXTEND) or (s[0] EQ 0) then $
          sxaddpar, header, 'EXTEND', 'T', ' File May Contain Extensions'
     Get_date, dte                       ;Get current date as CCYY-MM-DD
     sxaddpar, header, 'DATE', dte,' Creation date (CCYY-MM-DD) of FITS header'
  endelse

 if stype EQ 12 then sxaddpar, header,'O_BZERO',32768, $
            ' Original Data is Unsigned Integer'
 if stype EQ 13 then sxaddpar, header,'O_BZERO',2147483648, $
            ' Original Data is Unsigned Long'
 header = header[0:s[0]+7]

 end
