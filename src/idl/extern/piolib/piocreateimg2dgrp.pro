
;--------------------------------------------------------------#
;
; AUTOMATICALLY GENERATED DO NOT MODIFY 

;--------------------------------------------------------------#




;	Wrapping PIOCreateIMG2DGrp

FUNCTION PIOCREATEIMG2DGRP,Groupname,Proj,Coordsys,NAXIS1,NAXIS2,PixSize1,PixSize2,CRPixX,CRPixY,PV
     ON_ERROR,1
     PIOLibIDLSO=shared_lib_path('PIOLibIDL.so')
    Groupname_TMP=BYTARR(128)
    Groupname_TMP(*)=0
    if (N_ELEMENTS(Groupname) GT 0) THEN if (STRLEN(Groupname) GT 0) THEN Groupname_TMP(0:STRLEN(Groupname)-1)=BYTE(Groupname)
    Proj_TMP=BYTARR(128)
    Proj_TMP(*)=0
    if (N_ELEMENTS(Proj) GT 0) THEN if (STRLEN(Proj) GT 0) THEN Proj_TMP(0:STRLEN(Proj)-1)=BYTE(Proj)
    Coordsys_TMP=BYTARR(128)
    Coordsys_TMP(*)=0
    if (N_ELEMENTS(Coordsys) GT 0) THEN if (STRLEN(Coordsys) GT 0) THEN Coordsys_TMP(0:STRLEN(Coordsys)-1)=BYTE(Coordsys)
    if (N_ELEMENTS(NAXIS1) EQ 0) THEN     NAXIS1=LONG64(0) ELSE    NAXIS1=LONG64(NAXIS1)
     if (N_ELEMENTS(NAXIS2) EQ 0) THEN     NAXIS2=LONG64(0) ELSE    NAXIS2=LONG64(NAXIS2)
     if (N_ELEMENTS(PixSize1) EQ 0) THEN     PixSize1=FLOAT(0) ELSE    PixSize1=FLOAT(PixSize1)
     if (N_ELEMENTS(PixSize2) EQ 0) THEN     PixSize2=FLOAT(0) ELSE    PixSize2=FLOAT(PixSize2)
     if (N_ELEMENTS(CRPixX) EQ 0) THEN     CRPixX=DOUBLE(0) ELSE    CRPixX=DOUBLE(CRPixX)
     if (N_ELEMENTS(CRPixY) EQ 0) THEN     CRPixY=DOUBLE(0) ELSE    CRPixY=DOUBLE(CRPixY)
 IF (N_PARAMS() LT 10) THEN BEGIN
    PV=long64(0)
END ELSE BEGIN
    PV=long64(PV)
END

 PIOCREATEIMG2DGRP=call_external(PIOLibIDLSO,'piocreateimg2dgrp_tempoidl', $
        Groupname_TMP, $
        Proj_TMP, $
        Coordsys_TMP, $
        NAXIS1, $
        NAXIS2, $
        PixSize1, $
        PixSize2, $
        CRPixX, $
        CRPixY, $
        PV, $
               /L64_VALUE) 

 RETURN,PIOCREATEIMG2DGRP
END
