;+
; NAME:
;   logsheet
;
; PURPOSE:
;   Make a summary of header keywords in a directory of raw SDSS spectro files.
;
; CALLING SEQUENCE:
;   logsheet, [mjd=, camera=, outfile=]
;
; INPUTS:
;
; OPTIONAL INPUTS:
;   mjd        - Directory name; default to largest numbered MJD
;                matching the directory "$RAWDATA_DIR/?????".
;   camera     - Camera name of files to list; default to '??'
;                for all cameras.
;   outfile    - Output file
;
; OUTPUTS:
;
; COMMENTS:
;   First look at files matching "sdR*.fit.gz" in the directory
;   $RAWDATA_DIR/$MJD, and if none found then look for files
;   matching "sdR*.fit".
;
; EXAMPLES:
;   Print a log sheet of the most recent MJD:
;     IDL> logsheet
;
;   Print a log sheet of the most recent MJD, but only for the 'b1' camera:
;     IDL> logsheet, camera='b1'
;
;   Print a log sheet of the spectroscopic data from MJD=52000 (if it
;   still exists on disk), and write to the file 'junk.log'.
;     IDL> logsheet, mjd=52000, outfile='junk.log'
;
; PROCEDURES CALLED:
;   djs_filepath()
;   sdsshead()
;   sxpar()
;
; REVISION HISTORY:
;   06-Oct-1999  Written by David Schlegel, Princeton.
;-
;------------------------------------------------------------------------------
pro logsheet, mjd=mjd, camera=camera, outfile=outfile

   quiet = !quiet
   !quiet = 1

   if (NOT keyword_set(camera)) then camera = '??'

   ;----------
   ; Set input directory for sdR files

   rawdata_dir = getenv('RAWDATA_DIR')
   if (NOT keyword_set(rawdata_dir)) then $
    rawdata_dir = '/data/spectro'

   ;----------
   ; If MJD is not specified, then find the most recent MJD for output files

   if (NOT keyword_set(mjd)) then begin
      mjdlist = get_mjd_dir(rawdata_dir, mjstart=1, mjend=99999, mjd='?????')
      mjd = (reverse(mjdlist[sort(mjdlist)]))[0]
      splog, 'Selecting MJD=', mjd, ' (override this with MJD keyword)'
   endif

   ;----------
   ; First look at files matching "sdR*.fit.gz", and if none found
   ; then look for files matching "sdR*.fit".

   mjdstr = string(mjd, format='(i5.5)')
   filename = 'sdR-' + camera + '-*.fit'
   fullname = findfile(djs_filepath(filename+'.gz', $
    root_dir=rawdata_dir, subdir=mjdstr), count=nfile)
   if (nfile EQ 0) then $
    fullname = findfile(djs_filepath(filename, $
     root_dir=rawdata_dir, subdir=mjdstr), count=nfile)

   if (nfile EQ 0) then begin
      print, 'No files found.'
      !quiet = quiet
      return
   endif

   ; Open output file
   if (keyword_set(outfile)) then begin
      openw, olun, outfile, /get_lun
   endif else begin
      olun = -1
   endelse

   ; Remove the path from the file names
   shortname = strarr(nfile)
   for i=0, nfile-1 do begin
      res = str_sep(fullname[i],'/')
      shortname[i] = res[N_elements(res)-1]
   endfor

   ; Sort the files based upon exposure number + camera number
   isort = sort( strmid(shortname,7,8) + strmid(shortname,4,2) )
   fullname = fullname[isort]
   shortname = shortname[isort]

   printf, olun, $
    'UT      FILENAME        NAME           PLATE CART  EXPTIME FLAVOR    QUALITY  '
   printf, olun, $
    '------- --------------- -------------- ----- ----- ------- --------- ---------'

   for i=0, nfile-1 do begin
      hdr = sdsshead(fullname[i])

      jd = 2400000.5D + sxpar(hdr, 'TAI') / (24.D*3600.D)
      caldat, jd, jd_month, jd_day, jd_year, jd_hr, jd_min, jd_sec
      utstring = string(jd_hr, jd_min, format='(i2.2,":",i2.2," Z")')

      printname = strmid(shortname[i],0,15)
      plugname = sxpar(hdr, 'NAME') + '              '
      plateid = sxpar(hdr, 'PLATEID')
      cartid = sxpar(hdr, 'CARTID')
      exptime = sxpar(hdr, 'EXPTIME')
      flavor = sxpar(hdr, 'FLAVOR') + '         '
      quality = sxpar(hdr, 'QUALITY') + '         '

      ; Put a blank line before a new plate
      if (i EQ 0) then lastplate = plateid
      if (plateid NE lastplate) then begin
         printf, olun, ' '
         lastplate = plateid
      endif

      printf, olun, utstring, printname, $
       plugname, plateid, cartid, exptime, flavor, quality, $
       format='(a7, " ", a15, " ", a14, " ", i5, " ", i5, f8.1, " ", a9, " ", a9)'
   endfor

   ; Close output file
   if (keyword_set(outfile)) then begin
      close, olun
      free_lun, olun
   endif

   !quiet = quiet

   return
end
;------------------------------------------------------------------------------
