pro wmap_data2gnom, data, pol_data, pix_type, pix_param, do_conv, do_rot, coord_in, coord_out, eul_mat, $
               color, Tmax, Tmin, color_bar, dx, planvec, vector_scale, $
               PXSIZE=pxsize, PYSIZE=pysize, ROT=rot_ang, LOG=log, HIST_EQUAL=hist_equal, $
               MAX=max_set, MIN=min_set, $
               RESO_ARCMIN=reso_arcmin, FITS = fits, $
               FLIP=flip, DATA_plot = data_plot, $
               POLARIZATION=polarization

;+
;==============================================================================================
;     WMAP_DATA2GNOM
;
;     turns a Healpix or Quad-cube map into in Gnomonic rectangular map
;     This is identical to the procedure DATA2GNOM in the HealPix 1.2 library.
;     It is renamed here so as to avoid possible conflicts with the version
;     (with a different calling sequence) in the HealPix 1.1 library.
;
;     WMAP_DATA2GNOM,  data, pix_type, pix_param, do_conv, do_rot, coord_in, 
;          coord_out, eul_mat,
;          color, Tmax, Tmin, color_bar, dx, planvec, vector_scale,
;          pxsize=, pysize=, rot=, log=, hist_equal=, max=, min=,
;          reso_arcmin=, fits=, flip=, data_plot=, polarization=
;
; IN :
;      data, pix_type, pix_param, do_conv, do_rot, coord_in, coord_out, eul_mat
; OUT :
;      color, Tmax, Tmin, color_bar, dx, planvec, vector_scale
; KEYWORDS
;      Pxsize, Pysize, Rot, Log, Hist_equal, Max, Min, Reso_arcmin,
;      Fits, flip, data_plot, polarization
;
;  called by gnomview
;==============================================================================================
;-

proj_small = 'gnomic'
du_dv = 1.    ; aspect ratio
fudge = 1.00  ; 
if keyword_set(flip) then flipconv=1 else flipconv = -1  ; longitude increase leftward by default (astro convention)
if undefined(polarization) then polarization=0
do_polamplitude = (polarization eq 1)
do_poldirection = (polarization eq 2)
do_polvector    = (polarization eq 3)

!P.BACKGROUND = 1               ; white background
!P.COLOR = 0                    ; black foreground

mode_col = keyword_set(hist_equal)
mode_col = mode_col + 2*keyword_set(log)

npix = N_ELEMENTS(data)

bad_data= -1.63750000e+30

if (do_poldirection or do_polvector) then begin
    ; compute new position of pixelisation North Pole in the plot coordinates
    north_pole = [0.,0.,1.]
    if (do_conv) then north_pole = SKYCONV(north_pole, inco= coord_in, outco=coord_out)
    if (do_rot) then north_pole = north_pole # transpose(eul_mat)
endif
; -------------------------------------------------------------
; create the rectangular window
; -------------------------------------------------------------
if defined(pxsize) then xsize = pxsize*1L else xsize = 500L
if defined(pysize) then ysize = pysize*1L else ysize = xsize
if defined(reso_arcmin) then resgrid = reso_arcmin/60. else resgrid = 1.5/60.
dx      = resgrid * !DtoR
N_uv = xsize*ysize

print,'Input map  :  ',3600.*6./sqrt(!pi*npix),' arcmin / pixel ',form='(a,f8.3,a)'
print,'gnomonic map :',resgrid*60.,' arcmin / pixel ',xsize,'*',ysize,form='(a,f8.3,a,i4,a,i4)'

grid = FLTARR(xsize,ysize)
if do_polvector then planvec = MAKE_ARRAY(/FLOAT,xsize,ysize, 2, Value = bad_data) 
; -------------------------------------------------------------
; makes the projection around the chosen contact point
; -------------------------------------------------------------
; position on the planar grid  (1,u,v)
x0 = +1.
xll= 0 & xur =  xsize-1
yll= 0 & yur =  ysize-1
xc = 0.5*(xll+xur)  ; & deltax = (xur - xc)
yc = 0.5*(yll+yur)  ; & deltay = (yur - yc)

yband = LONG(5.e5 / FLOAT(xsize))
for ystart = 0, ysize - 1, yband do begin 
    yend   = (ystart + yband - 1) < (ysize - 1)
    nband = yend - ystart + 1
    npb = xsize * nband
    u = flipconv*(FINDGEN(xsize) - xc)# REPLICATE(dx,nband)   ; minus sign = astro convention
    v =           REPLICATE(dx,xsize) # (FINDGEN(nband) + ystart - yc)
    x = replicate(x0, npb)
    vector = [[x],[reform(u,npb,/over)],[reform(v,npb,/over)]] ; non normalised vector
    ; --------------------------------
    ; deal with polarisation direction
    ; --------------------------------
    if (do_poldirection or do_polvector) then begin
        phi = 0.
        if (do_rot or do_conv) then begin
            vector = vector / (sqrt(total(vector^2, 2))#replicate(1,3)) ; normalize vector
            ; compute rotation of local coordinates around each vector
            tmp_sin = north_pole[1] * vector[*,0] - north_pole[0] * vector[*,1]
            tmp_cos = north_pole[2] - vector[*,2] * (north_pole[0:2] ## vector)
            if (flipconv lt 0) then tmp_cos = flipconv * tmp_cos
            phi = ATAN(tmp_sin, tmp_cos) ; angle in radians
            tmp_sin = 0. & tmp_cos = 0
        endif
    endif
    ; ---------
    ; rotation
    ; ---------
    if (do_rot) then vector = vector # eul_mat
    if (do_conv) then vector = SKYCONV(vector, inco = coord_out, outco =  coord_in)
          ; we go from the final Gnomonic map (system coord_out) to
          ; the original one (system coord_in)
    ; -------------------------------------------------------------
    ; converts the position on the sphere into pixel number
    ; and project the corresponding data value on the map
    ; -------------------------------------------------------------
    case pix_type of
        'R' : VEC2PIX_RING, pix_param, vector, id_pix ; Healpix ring
        'N' : VEC2PIX_NEST, pix_param, vector, id_pix ; Healpix nest
        'Q' : id_pix = UV2PIX(vector, pix_param) ; QuadCube (COBE cgis software)
        else : print,'error on pix_type'
    endcase
    if (do_poldirection) then begin
        grid[ystart*xsize] = (data[id_pix] - phi + 4*!PI) MOD (2*!PI) ; in 0,2pi
    endif else if (do_polvector) then begin
        grid[ystart*xsize]         = data[id_pix]
        planvec[ystart*xsize]      = pol_data[id_pix,0]
        planvec[ystart*xsize+n_uv] = (pol_data[id_pix,1] - phi + 4*!PI) MOD (2*!PI); angle
    endif else begin
        grid[ystart*xsize] = data[id_pix]
    endelse
endfor
u = 0 & v = 0 & x = 0 & vector = 0

; -------------------------------------------------------------
; Test for unobserved pixels
; -------------------------------------------------------------
data_plot = temporary(data)
pol_data = 0
mindata = MIN(grid,MAX=maxdata)
if (mindata le (bad_data*.9) or (1 - finite(total(grid)))) then begin
    Obs    = where( grid gt (bad_data*.9) and finite(grid), N_Obs )
    if (N_Obs gt 0) then mindata = MIN(grid[Obs],max=maxdata)
endif else begin 
    if defined(Obs) then begin
        Obs = 0
        junk = temporary(Obs)   ; Obs is not defined
    endif
endelse

;-----------------------------------
; export in fits the original gnomic map before alteration
;-----------------------------------

if keyword_set(fits) then begin 
    if (rot_ang(2) NE 0.) then begin 
        print,'can NOT export gnomic FITS file'
        print,'set Rot = [lon0, lat0, 0.0]'
        goto,skip_fits
    endif
    if (DATATYPE(fits) ne 'STR') then file_fits = 'plot_'+proj_small+'.fits' else file_fits = fits
    gnom2fits, grid, file_fits, rot = rot_ang, coord=coord_out, reso = resgrid*60., unit = sunits, min=mindata, max = maxdata
    print,'FITS file is in '+file_fits
    skip_fits:
endif

; -------------------------------------------------------------
; set min and max and computes the color scaling
; -------------------------------------------------------------
if (do_poldirection) then begin
    min_set = 0.
    max_set = 2*!pi
endif
color = COLOR_MAP(grid, mindata, maxdata, Obs, $
         color_bar = color_bar, mode=mode_col, minset = min_set, maxset = max_set )
if (do_polvector) then begin    ; rescale polarisation vector in each valid pixel
    planvec[*,*,0] = vector_map(planvec[*,*,0], Obs, vector_scale = vector_scale)
endif
Obs = 0
grid = 0
Tmin = mindata & Tmax = maxdata

return
end

