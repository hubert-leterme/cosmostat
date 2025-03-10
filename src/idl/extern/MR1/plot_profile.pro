pro plot_profile, image, sx = sx, sy = sy, wsize = wsize, order = order, zoom=zoom
;+
; NAME:
;	PLOT_PROFILE
;
; PURPOSE:
;	Interactively draw row or column profiles of an image in a separate
;	window. This routine is extracted from the User Library, and has
;       been modified. A plot is drawn only when the user click on the 
;       left mouse button, and a zoom factor has been introduced for the
;       case where the image in the window has been zoomed
;
; CALLING SEQUENCE:
;	PLOT_PROFILE, Image [, SX = sx, SY = sy, wsize = wsize, order = order]
;
; INPUTS:
;	Image -- array :	The variable that represents the image displayed in current 
;		window.  This data need not be scaled into bytes.
;		The profile graphs are made from this array.
;
; OPTIONAL INPUT PARAMETERS:  none
;
;  KEYED INPUTS:
;	SX -- scalar :	Starting X position of the image in the window.  If this 
;		keyword is omitted, 0 is assumed.
;
;	SY -- scalar:	Starting Y position of the image in the window.  If this
;		keyword is omitted, 0 is assumed.
;
;	WSIZE -- scalar:	The size of the PROFILES window as a fraction or multiple 
;		of 640 by 512.
;
;	ORDER -- scalar:	Set this keyword param to 1 for images written top down or
;		0 for bottom up.  Default is the current value of !ORDER.
;
;        ZOOM -- scalar :  Zoom facted between the display image and input image
;
; EXAMPLE:
;	Create and display an image and use the PLOT_PROFIL routine on it.
;	Create and display the image by entering:
;
;		A = BYTSCL(DIST(256))
;		TV, A
;
;	Run the PLOT_PROFILE routine by entering:
;
;		PLOT_PROFILE, A
;
;	The PLOT_PROFILE window should appear. Move the cursor over the original
;	image and press the left mouse button to see the  profile at the cursor
;       position.  Press the  middle mouse  button  to toggle between  row  and 
;       column  profiles.  Press the right mouse button (with  the cursor  over
;       the original image) to exit the routine.
;
; ALGORITHM:
;	A new window is created and the mouse location in the original
;	window is used to plot profiles in the new window.  Pressing the
;	middle mouse button toggles between row and column profiles.
;	The right mouse button exits.
;
;
; MODIFICATION HISTORY:
;	DMS, Nov, 1988.
;    14-MAR-1996 J. SAM LONE: update header
;
;-
on_error,2                              ;Return to caller if an error occurs

if not keyword_set(zoom) then zoom = 1

if n_elements(sx) eq 0 then sx = 0	;Default start of image
if n_elements(sy) eq 0 then sy = 0
if n_elements(wsize) eq 0 then wsize = .75
s = size(image)
maxv = max(image) 			;Get extrema
minv = min(image)
orig_w = !d.window
nx = s(1)				;Cols in image
ny = s(2)				;Rows in image
IF (!Version.Os NE 'MacOS') THEN tvcrs,sx+nx/2,sy+ny/2,/dev ELSE tvcrs,1
tickl = 0.1				;Cross length
print,'Middle mouse button to toggle between rows and columns.'
print,'Left to display and Right mouse button to Exit.'
window,/free ,xs=wsize*640, ys=wsize*512,title='Profiles' ;Make new window
new_w = !d.window
old_mode = -1				;Mode = 0 for rows, 1 for cols
old_font = !p.font			;Use hdw font
!p.font = 0
mode = 0
if n_elements(order) eq 0 then order = !order	;Image order

while 1 do begin
	wset,orig_w		;Image window
	cursor,x,y,2,/dev	;Read position

	if !err eq 2 then begin
		mode = 1-mode	;Toggle mode
;		repeat cursor,x,y,0,/dev until !err eq 0
		endif

	if (x - sx) GE 0 then x = fix((x - sx) / zoom) $
	else x = fix((x - sx) / zoom-1)

	if (y - sy) GE 0 then y = fix((y - sy) / zoom) $
	else y = fix((y - sy) / zoom-1)

	wset,new_w		;Graph window

	if !err eq 4 then begin		;Quit
		wset,orig_w
		IF (!Version.Os NE 'MacOS') THEN $
			tvcrs,nx/2,ny/2,/dev	;curs to old window
		tvcrs,0				;Invisible
		wdelete, new_w
		!p.font = old_font
		return
		endif

	if (!err eq 1) or (!err eq 2) then BEGIN
;	if mode ne old_mode then begin
		old_mode = mode
		first = 1
		if mode then begin	;Columns?
                        t ='Column Profile '+strcompress(string(x),/REMOVE_ALL)
			plot,[minv,maxv],[0,ny-1],/nodat,title=t
			vecy = findgen(ny)
			crossx = [-tickl, tickl]*(maxv-minv)
			crossy = [-tickl, tickl]*ny
		end else begin
                        t ='Row Profile '+strcompress(string(y),/REMOVE_ALL)
			plot,[0,nx-1],[minv,maxv],/nodata,title=t
			vecx = findgen(nx)
			crossx = [-tickl, tickl]*nx
			crossy = [-tickl, tickl]*(maxv-minv)
		endelse
;	endif

	if (x lt nx) and (y lt ny) and $
		(x ge 0) and (y ge 0) then begin	;Draw it
		
		if order then y = (ny-1)-y	;Invert y?
		if first eq 0 then begin	;Erase?
			plots, vecx, vecy, col=0	;Erase graph
			plots, old_x, old_y, col=0	;Erase cross
			plots, old_x1, old_y1, col=0
			xyouts,.1,0,/norm,value,col=0	;Erase text
			empty
		  endif else first = 0
;;;;		value = string([x,y],format="('(',i4,',',i4,')')")
;;;;		value = strtrim(x,2) + string(y)
		value = strmid(x,8,4)+strmid(y,8,4)
		ixy = image(x,y)		;Data value
		if mode then begin		;Columns?
			vecx = image(x,*)	;get column
			old_x = crossx + ixy
			old_y = [y,y]
			old_x1 = [ixy, ixy]
			old_y1 = crossy + y
		  endif else begin
			vecy = image(*,y)	;get row
			old_x = [ x,x]
			old_y = crossy + ixy
			old_x1 = crossx + x
			old_y1 = [ixy,ixy]
		  endelse
		xyouts,.1,0,/norm,value	;Text of locn
		plots,vecx,vecy		;Graph
		plots,old_x, old_y	;Cross
		plots,old_x1, old_y1
		endif
          END
endwhile
end
