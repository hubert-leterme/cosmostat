pro aper,image,xc,yc,mags,errap,sky,skyerr,phpadu,apr,skyrad,badpix, $
       SETSKYVAL = setskyval,PRINT = print, SILENT = silent, FLUX=flux, $
       EXACT = exact
;+
; NAME:
;      APER
; PURPOSE:
;      Compute concentric aperture photometry (adapted from DAOPHOT) 
; EXPLANATION:
;     APER can compute photometry in several user-specified aperture radii.  
;     A separate sky value is computed for each source using specified inner 
;     and outer sky radii.   
;
; CALLING SEQUENCE:
;     APER, image, xc, yc, [ mags, errap, sky, skyerr, phpadu, apr, skyrad, 
;                       badpix, /EXACT, /FLUX, PRINT = , /SILENT, SETSKYVAL = ]
; INPUTS:
;     IMAGE -  input image array
;     XC     - vector of x coordinates. 
;     YC     - vector of y coordinates
;
; OPTIONAL INPUTS:
;     PHPADU - Photons per Analog Digital Units, numeric scalar.  Converts
;               the data numbers in IMAGE to photon units.  (APER assumes
;               Poisson statistics.)  
;     APR    - Vector of up to 12 REAL photometry aperture radii.
;     SKYRAD - Two element vector giving the inner and outer radii
;               to be used for the sky annulus
;     BADPIX - Two element vector giving the minimum and maximum value
;               of a good pix (Default [-32765,32767])
;
; OPTIONAL KEYWORD INPUTS:
;     /EXACT -  By default, APER counts subpixels, but uses a polygon 
;             approximation for the intersection of a circular aperture with
;             a square pixel (and normalize the total area of the sum of the
;             pixels to exactly match the circular area).   If the /EXACT 
;             keyword, then the intersection of the circular aperture with a
;             square pixel is computed exactly.    The /EXACT keyword is much
;             slower and is only needed when small (~2 pixels) apertures are
;             used with very undersampled data.    
;     /FLUX - By default, APER uses a magnitude system where a magnitude of
;               25 corresponds to 1 flux unit.   If set, then APER will keep
;              results in flux units instead of magnitudes.
;     PRINT - if set and non-zero then APER will also write its results to
;               a file aper.prt.   One can specify the output file name by
;               setting PRINT = 'filename'.
;     /SILENT -  If supplied and non-zero then no output is displayed to the
;               terminal.
;     SETSKYVAL - Use this keyword to force the sky to a specified value 
;               rather than have APER compute a sky value.    SETSKYVAL 
;               can either be a scalar specifying the sky value to use for 
;               all sources, or a 3 element vector specifying the sky value, 
;               the sigma of the sky value, and the number of elements used 
;               to compute a sky value.   The 3 element form of SETSKYVAL
;               is needed for accurate error budgeting.
;
; OUTPUTS:
;     MAGS   -  NAPER by NSTAR array giving the magnitude for each star in
;               each aperture.  (NAPER is the number of apertures, and NSTAR
;               is the number of stars).   A flux of 1 digital unit is assigned
;               a zero point magnitude of 25.
;     ERRAP  -  NAPER by NSTAR array giving error in magnitude
;               for each star.  If a magnitude could not be deter-
;               mined then ERRAP = 9.99.
;     SKY  -    NSTAR element vector giving sky value for each star
;     SKYERR -  NSTAR element vector giving error in sky values
;
; PROCEDURES USED:
;       DATATYPE(), GETOPT, MMM, PIXWT(), STRN(), STRNUMBER()
; NOTES:
;       Reasons that a valid magnitude cannot be computed include the following:
;      (1) Star position is too close (within 0.5 pixels) to edge of the frame
;      (2) Less than 20 valid pixels available for computing sky
;      (3) Modal value of sky could not be computed by the procedure MMM
;      (4) *Any* pixel within the aperture radius is a "bad" pixel
;
;       APER was modified in June 2000 in two ways: (1) the /EXACT keyword was
;       added (2) the approximation of the intersection of a circular aperture
;       with square pixels was improved (i.e. when /EXACT is not used) 
; REVISON HISTORY:
;       Adapted to IDL from DAOPHOT June, 1989   B. Pfarr, STX
;       Adapted for IDL Version 2,               J. Isensee, July, 1990
;       Code, documentation spiffed up           W. Landsman   August 1991
;       TEXTOUT may be a string                  W. Landsman September 1995
;       FLUX keyword added                       J. E. Hollis, February, 1996
;       SETSKYVAL keyword, increase maxsky       W. Landsman, May 1997
;       Work for more than 32767 stars           W. Landsman, August 1997
;       Converted to IDL V5.0                    W. Landsman   September 1997
;       Don't abort for insufficient sky pixels  W. Landsman  May 2000
;       Added /EXACT keyword                     W. Landsman  June 2000 
;       Allow SETSKYVAL = 0                      W. Lansdman  December 2000      
;-
 On_error,2
;             Set parameter limits
 minsky = 20   ;Smallest number of pixels from which the sky may be determined
 maxrad = 100.          ;Maximum outer radius permitted for the sky annulus.
 maxsky = 10000         ;Maximum number of pixels allowed in the sky annulus.
;                                
if N_params() LT 3 then begin    ;Enough parameters supplied?
  print, $
  'Syntax - APER, image, xc, yc, [ mags, errap, sky, skyerr, phpadu, apr, '
  print,'             skyrad, badpix, /EXACT, /FLUX, SETSKYVAL = ,PRINT =, ]'
  return
endif 

 s = size(image)
 if ( s[0] NE 2 ) then message, $
       'ERROR - Image array (first parameter) must be 2 dimensional'
 ncol = s[1] & nrow = s[2]           ;Number of columns and rows in image array

  silent = keyword_set(SILENT)


 if N_elements(badpix) NE 2 then begin ;Bad pixel values supplied
GET_BADPIX:  
   ans = ''
   print,'Enter low and high bad pixel values, [RETURN] for defaults'
   read,'Low and high bad pixel values [-32765,32767]: ',ans
   if ans EQ  '' then badpix = [-32765,32767] else begin
   badpix = getopt(ans,'F')
   if ( N_elements(badpix) NE 2 ) then begin
        message,'Expecting 2 scalar values',/continue
        goto,GET_BADPIX
   endif
   endelse
 endif 

 if ( N_elements(apr) LT 1 ) then begin              ;Read in aperture sizes?
   apr = fltarr(10)
   read, 'Enter first aperture radius: ',ap
   apr[0] = ap
   ap = 'aper'
   for i = 1,9 do begin                                                   
GETAP: 
      read,'Enter another aperture radius, [RETURN to terminate]: ',ap
      if ap EQ '' then goto,DONE  
      result = strnumber(ap,val)
      if result EQ 1 then apr[i] = val else goto, GETAP   
   endfor
DONE: 
   apr = apr[0:i-1]
 endif


 if N_elements(SETSKYVAL) GT 0 then begin
     if N_elements( SETSKYVAL ) EQ 1 then setskyval = [setskyval,0.,1.]
     if N_elements( SETSKYVAL ) NE 3 then message, $
        'ERROR - Keyword SETSKYVAL must contain 1 or 3 elements'
     skyrad = [ 0., max(apr) + 1]
 endif

;Get radii of sky annulii

 if N_elements(skyrad) NE 2 then begin
   skyrad = fltarr(2)
   read,'Enter inner and outer sky radius (pixel units): ',skyrad
 endif else skyrad = float(skyrad)

 if ( N_elements(phpadu) LT 1 ) then $ 
   read,'Enter scale factor in Photons per Analog per Digital Unit: ',phpadu

 Naper = N_elements( apr )                        ;Number of apertures
 Nstars = min([ N_elements(xc), N_elements(yc) ])  ;Number of stars to measure

 ms = strarr( Naper )       ;String array to display mag for each aperture
 if keyword_set(flux) then $
          fmt = '(F8.1,1x,A,F7.1)' else $           ;Flux format
          fmt = '(F9.3,A,F5.3)'                  ;Magnitude format
 fmt2 = '(I5,2F8.2,F7.2,3A,3(/,28x,4A,:))'       ;Screen format
 fmt3 = '(I4,5F8.2,6A,2(/,44x,9A,:))'            ;Print format

 mags = fltarr( Naper, Nstars) & errap = mags           ;Declare arrays
 sky = fltarr( Nstars )        & skyerr = sky     
 area = !PI*apr*apr                 ;Area of each aperture
 apmag= fltarr(Naper)   & magerr = apmag   
                      error1=apmag   & error2 = apmag   & error3 = apmag

 if keyword_set(EXACT) then begin
      bigrad = apr + 0.5
      smallrad = apr/sqrt(2) - 0.5 
 endif
     

 if N_elements(SETSKYVAL) EQ 0 then begin

 if skyrad[1] GT maxrad then begin
     message,/INF,'WARNING - Outer sky radius being reset to '+ strn(maxrad) 
     skyrad[1] = (maxrad-0.001)        ;Outer sky radius less than MAXRAD?
 endif
     rinsq =  (skyrad[0]> 0.)^2 
     routsq = skyrad[1]^2
 endif 

 if keyword_set(PRINT) then begin      ;Open output file and write header info?
   if datatype(PRINT) NE 'STR'  then file = 'aper.prt' $
                                   else file = print
   message,'Results will be written to a file ' + file,/INF
   openw,lun,file,/GET_LUN
   printf,lun,' Program: APER '+ systime(), '   User: ', $
      getenv('USER'),'  Node: ',getenv('NODE')
   for j = 0, Naper-1 do printf,lun, $
               format='(a,i2,a,f4.1)','Radius of aperture ',j,' = ',apr[j]
   printf,lun,f='(/a,f4.1)','Inner radius for sky annulus = ',skyrad[0]
   printf,lun,f='(a,f4.1)', 'Outer radius for sky annulus = ',skyrad[1]
   if keyword_set(FLUX) then begin
       printf,lun,f='(/a)', $
           'STAR   X       Y        SKY   SKYSIG    SKYSKW   FLUXES'
      endif else printf,lun,f='(/a)', $
           'STAR   X       Y        SKY   SKYSIG    SKYSKW   MAGNITUDES'
 endif
 print = keyword_set(PRINT)

;         Print header
 if not SILENT then begin
    if (KEYWORD_SET(FLUX)) then begin
       print, format="(/1X,'STAR',5X,'X',7X,'Y',6X,'SKY',8X,'FLUXES')"
    endif else print, $ 
       format="(/1X,'STAR',5X,'X',7X,'Y',6X,'SKY',8X,'MAGNITUDES')" 
 endif

;  Compute the limits of the submatrix.   Do all stars in vector notation.

 lx = fix(xc-skyrad[1]) > 0           ;Lower limit X direction
 ux = fix(xc+skyrad[1]) < (ncol-1)    ;Upper limit X direction
 nx = ux-lx+1                         ;Number of pixels X direction
 ly = fix(yc-skyrad[1]) > 0           ;Lower limit Y direction
 uy = fix(yc+skyrad[1]) < (nrow-1);   ;Upper limit Y direction
 ny = uy-ly +1                        ;Number of pixels Y direction
 dx = xc-lx                         ;X coordinate of star's centroid in subarray
 dy = yc-ly                         ;Y coordinate of star's centroid in subarray

 edge = (dx-0.5) < (nx+0.5-dx) < (dy-0.5) < (ny+0.5-dy) ;Closest edge to array
 badstar = ((xc LT 0.5) or (xc GT ncol-1.5) $  ;Stars too close to the edge
        or (yc LT 0.5) or (yc GT nrow-1.5))
;
 badindex = where( badstar, Nbad)              ;Any stars outside image
 if ( Nbad GT 0 ) then message, /INF, $
      'WARNING - ' + strn(nbad) + ' star positions outside image'
 
 for i = 0L, Nstars-1 do begin           ;Compute magnitudes for each star
   skymod = 0. & skysig = 0. &  skyskw = 0.  ;Sky mode sigma and skew
   if badstar[i] then begin         ;
      apmag[*] = -1.0E-36
      goto, BADSTAR 
   endif

   rotbuf = image[ lx[i]:ux[i], ly[i]:uy[i] ] ;Extract subarray from image
;  RSQ will be an array, the same size as ROTBUF containing the square of
;      the distance of each pixel to the center pixel.

 
    dxsq = ( findgen( nx[i] ) - dx[i] )^2
    rsq = fltarr( nx[i], ny[i], /NOZERO )
   for ii = 0, ny[i]-1 do rsq[0,ii] = dxsq + (ii-dy[i])^2


 if keyword_set(exact) then begin 
       nbox = lindgen(nx[i]*ny[i])
       xx = reform( (nbox mod nx[i]), nx[i], ny[i])
       yy = reform( (nbox/nx[i]),nx[i],ny[i])
       x1 = abs(xx-dx[i]) 
       y1 = abs(yy-dy[i])
  endif else begin 
   r = sqrt(rsq) - 0.5    ;2-d array of the radius of each pixel in the subarray
 endelse

;  Select pixels within sky annulus, and eliminate pixels falling
;       below BADLO threshold.  SKYBUF will be 1-d array of sky pixels
 if N_elements(SETSKYVAL) EQ 0 then begin

 sindex =  where( ( rsq GE rinsq ) and ( rsq LE routsq ) and  $ 
                  ( rotbuf GT badpix[0] ) )
 nsky =   N_elements(sindex) < maxsky   ;Must be less than MAXSKY pixels
 skybuf = rotbuf[ sindex[0:nsky-1] ]     
 if ( nsky LT minsky ) then begin                       ;Sufficient sky pixels?
    if not silent then $
        message,'There aren''t enough valid pixels in the sky annulus.',/con
    mags[*,i] = -1.0e36
    goto, BADSTAR
 endif else  mmm, skybuf, skymod, skysig, skyskw

;  Obtain the mode, standard deviation, and skewness of the peak in the
;      sky histogram, by calling MMM.

 skyvar = skysig^2    ;Variance of the sky brightness
 sigsq = skyvar/nsky  ;Square of standard error of mean sky brightness

 if ( skysig LT 0.0 ) then begin   ;If the modal sky value could not be
       apmag[*] = -99.999          ;determined, then all apertures for
       goto, BADSTAR               ;this star are bad.
 endif  

 skysig = skysig < 999.99      ;Don't overload output formats
 skyskw = skyskw >(-99)<999.9
 endif else begin
    skymod = setskyval[0]
    skysig = setskyval[1]
    nsky = setskyval[2]
    skyvar = skysig^2
    sigsq = skyvar/nsky
    skyskw = 0
endelse



 for k = 0,Naper-1 do begin      ;Find pixels within each aperture

   if ( edge[i] LT apr[k] ) then $   ;Does aperture extend outside the image?
           apmag[k] = -1.0E36 $
   else begin
     if keyword_set(EXACT) then begin
       mask = fltarr(nx[i],ny[i])
       good = where( ( x1 LT smallrad[k] ) and (y1 LT smallrad[k] ), Ngood)
       if Ngood GT 0 then mask(good) = 1.0
       bad = where(  (x1 GT bigrad[k]) or (y1 GT bigrad ))
       mask(bad) = -1

       gfract = where(mask EQ 0.0, Nfract) 
       if Nfract GT 0 then mask[gfract] = $
		PIXWT(dx[i],dy[i],apr[k],xx[gfract],yy[gfract]) > 0.0
       thisap = where(mask GT 0.0)
       thisapd = rotbuf[thisap]
       fractn = mask[thisap]
     endif else begin
;
       thisap = where( r LT apr[k] )   ;Select pixels within radius
       thisapd = rotbuf[thisap]
       thisapr = r[thisap]
       fractn = (apr[k]-thisapr < 1.0 >0.0 ) ;Fraction of pixels to count
       full = fractn EQ 1.0
       gfull = where(full, Nfull)
       gfract = where(1 - full)
       factor = (area[k] - Nfull ) / total(fractn[gfract])
      fractn[gfract] = fractn[gfract]*factor
    endelse

;     If the pixel is bad, set the total counts in this aperture to a large
;        negative number
;
   if ( (min(thisapd) LE badpix[0] ) or ( max(thisapd) GE badpix[1]) ) then $
      apmag[k] = -1.0E36 $
   else begin
      apmag[k] = total(thisapd*fractn)  ;Total over irregular aperture
     endelse
  endelse
 endfor ;k

 apmag = apmag - skymod*area  ;Subtract sky from the integrated brightnesses

 good = where (apmag GT 0.0, Ngood)     ;Are there any valid integrated fluxes?
 if ( Ngood GT 0 ) then begin               ;If YES then compute errors
   error1[good] = area[good]*skyvar   ;Scatter in sky values
   error2[good] = apmag[good]/phpadu  ;Random photon noise 
   error3[good] = sigsq*area[good]^2  ;Uncertainty in mean sky brightness
   magerr[good] = sqrt(error1[good] + error2[good] + error3[good])

   if not keyword_set(FLUX) then begin
   magerr[good] = 1.0857*magerr[good]/apmag[good]   ;1.0857 = log(10)/2.5
   apmag[good] =  25.-2.5*alog10(apmag[good])  
   endif
 endif  

 BADSTAR:   
                                           ;Assign fluxes to bad stars
 nogood = where (apmag LE 0.0, Nbad) 
 if ( nbad GT 0 ) then begin               
        apmag[nogood] = 99.999
        magerr[nogood] = 9.999
 endif

;Print out magnitudes for this star

 for ii = 0,Naper-1 do $              ;Concatenate mags into a string

    ms[ii] = string( apmag[ii],'+-',magerr[ii], FORM = fmt)
   if PRINT then  printf,lun, $      ;Write results to file?
      form = fmt3,  i, xc[i], yc[i], skymod, skysig, skyskw, ms
   if not SILENT then print,form = fmt2, $       ;Write results to terminal?
          i,xc[i],yc[i],skymod,ms

   sky[i] = skymod    &  skyerr[i] = skysig  ;Store in output variable
   mags[0,i] = apmag  &  errap[0,i]= magerr
 endfor                                              ;i

 if PRINT then free_lun, lun             ;Close output file

 return
 end
