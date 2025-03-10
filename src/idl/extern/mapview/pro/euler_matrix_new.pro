function euler_matrix_new,a1,a2,a3,X=x,Y=y,ZYX=zyx,DEG=deg
;+
; NAME:
;         EULER_MATRIX_NEW
;
; PURPOSE:
;         computes the Euler matrix of an arbitrary rotation described
;         by 3 Euler angles
;         correct bugs present in Euler_Matrix
;        
; CALLING SEQUENCE:
;         result = euler_matrix_new (a1, a2, a3 [,X, Y, ZYX, DEG ])
; 
; INPUTS:
;         a1, a2, a3 = Euler angles, scalar
;	       (in radian by default, in degree if DEG is set)
;	       all the angles are measured counterclockwise
;      
;         correspond to x, y, zyx-conventions (see Goldstein)
;        the default is x
;
; KEYWORD PARAMETERS:
;       DEG : if set the angle are measured in degree
;
; 	X : 	rotation a1 around original Z 
;     		rotation a2 around interm   X 
;     		rotation a3 around final    Z
;	DEFAULT,  classical mechanics convention
;
;
; 	Y : 	rotation a1 around original Z
;     		rotation a2 around interm   Y
;     		rotation a3 around final    Z
;	quantum mechanics convention
;
;
; 	ZYX : 	rotation a1 around original Z
;     		rotation a2 around interm   Y
;     		rotation a3 around final    X
;	aeronautics convention
;
;       * these last three keywords are obviously mutually exclusive *
;
; OUTPUTS:
;       result is a 3x3 matrix
;
; USAGE: if vec is an Nx3 array containing N 3D vectors,
;    vec # euler_matrix_new(a1,a2,a3,/Y) will be the rotated vectors
;
;
; MODIFICATION HISTORY:
;	March 2002, EH, Caltech, rewritting of euler_matrix
;
;  convention   euler_matrix_new           euler_matrix
;      X:       M_new(a,b,c,/X)  =  M_old(-a,-b,-c,/X) = Transpose( M_old(c, b, a,/X))
;      Y:       M_new(a,b,c,/Y)  =  M_old(-a, b,-c,/Y) = Transpose( M_old(c,-b, a,/Y))
;    ZYX:       M_new(a,b,c,/Z)  =  M_old(-a, b,-c,/Z)
;
;-

if (n_params() ne 3) then begin
    message,'  Invalid number of arguments ',/noprefix,/inform
    message,' Syntax : result = euler_matrix(a1,a2,a3,[X=,Y=,ZYX=,Deg=])',/noprefix,/noname
endif

t_k = 0
IF KEYWORD_SET(zyx) THEN t_k = t_k + 1
IF KEYWORD_SET(x  ) THEN t_k = t_k + 1
IF KEYWORD_SET(y  ) THEN t_k = t_k + 1
IF t_k GT 1 THEN BEGIN
	message, 'incompatible keywords choice',/noprefix
ENDIF

convert = 1.0
IF KEYWORD_SET(deg) THEN convert = !DtoR

c1 = COS(a1*convert)
s1 = SIN(a1*convert)
c2 = COS(a2*convert)
s2 = SIN(a2*convert)
c3 = COS(a3*convert)
s3 = SIN(a3*convert)


if (keyword_set(ZYX)) then begin

m1 = [[ c1,-s1,  0],[ s1, c1,  0],[  0,  0,  1]] ; around   z
m2 = [[ c2,  0, s2],[  0,  1,  0],[-s2,  0, c2]] ; around   y
m3 = [[  1,  0,  0],[  0, c3,-s3],[  0, s3, c3]] ; around   x

endif else if (keyword_set(Y)) then begin

m1 = [[ c1,-s1,  0],[ s1, c1,  0],[  0,  0,  1]] ; around   z
m2 = [[ c2,  0, s2],[  0,  1,  0],[-s2,  0, c2]] ; around   y
m3 = [[ c3,-s3,  0],[ s3, c3,  0],[  0,  0,  1]] ; around   z

endif else begin

m1 = [[ c1,-s1,  0],[ s1, c1,  0],[  0,  0,  1]] ; around   z
m2 = [[  1,  0,  0],[  0, c2,-s2],[  0, s2, c2]] ; around   x
m3 = [[ c3,-s3,  0],[ s3, c3,  0],[  0,  0,  1]] ; around   z

endelse

; A ## B = matrix product AB
; A # B  = matrix product BA
; vec # A = product A.vec  if A is 3x3 and vec is nx3


euler_matrix = m3 # ( m2 # m1) ; m1 m2 m3


return, euler_matrix
end

