 pro kstwo, data1, data2, D, prob
;+
; NAME:
;       KSTWO
; PURPOSE:
;       Return the two-sided Kolmogorov-Smirnov statistic
; EXPLANATION:
;       Returns the Kolmogorov-Smirnov statistic and associated probability 
;       that two arrays of data values are drawn from the same distribution
;       Algorithm taken from procedure of the same name in "Numerical
;       Recipes" by Press et al., 2nd edition (1992), Chapter 14
;
; CALLING SEQUENCE:
;       kstwo, data1, data2, D, prob
;
; INPUT PARAMATERS:
;       data1 -  vector of data values, at least 4 data values must be included
;               for the K-S statistic to be meaningful
;       data2 -  second set of data values, does not need to have the same 
;               number of elements as data1
;
; OUTPUT PARAMETERS:
;       D - floating scalar giving the Kolmogorov-Smirnov statistic.   It
;               specifies the maximum deviation between the cumulative 
;               distribution of the data and the supplied function 
;       prob - floating scalar between 0 and 1 giving the significance level of
;               the K-S statistic.   Small values of PROB show that the 
;               cumulative distribution function of DATA1 is significantly 
;               different from DATA2
;
; EXAMPLE:
;       Test whether two vectors created by the RANDOMN function likely came
;       from the same distribution
;
;       IDL> data1 = randomn(seed,40)        ;Create data vectors to be 
;       IDL> data2 = randomn(seed,70)        ;compared
;       IDL> kstwo, data1, data2, D, prob   & print,D,prob
;
; PROCEDURE CALLS
;       procedure PROB_KS - computes significance of K-S distribution
;
; REVISION HISTORY:
;       Written     W. Landsman                August, 1992
;       FP computation of N_eff      H. Ebeling/W. Landsman  March 1996
;       Converted to IDL V5.0   W. Landsman   September 1997
;-
  On_error, 2

 if ( N_params() LT 4 ) then begin
    print,'Syntax - kstwo, data1, data2, d, prob'
    return
 endif

 n1 = N_elements( data1 )
 if ( N1 LE 3 ) then message, $
   'ERROR - Input data values (first param) must contain at least 4 values'

 n2 = N_elements( data2 )
 if ( n2 LE 3 ) then message, $
   'ERROR - Input data values (second param) must contain at least 4 values'

 sortdata1 = data1[ sort( data1 ) ]        ;Sort input arrays into 
 sortdata2 = data2[ sort( data2 ) ]        ;ascending order

 fn1 = ( findgen( n1 )  ) / n1
 fn2 = ( findgen( n2 )  ) / n2

 j1 = 0l & j2 = 0l
 id1 = lonarr(n1+n2)  & id2 = id1
 i = 0l

; Form the two cumulative distribution functions, marking points where one
; must test their difference

 while ( j1 LT N1 ) and ( j2 LT n2 ) do begin

     if sortdata1[j1] LE sortdata2[j2] then j1 = j1 +1 else $
     if sortdata2[j2] LE sortdata1[j1] then j2 = j2 +1
            
     id1[i] = j1   & id2[i] = j2
     i = i+1

 endwhile

 id1 = id1[0:i-1]   &  id2 = id2[0:i-1]

; The K-S statistic D is the maximum difference between the two distribution
; funtions

 D = max( abs( fn1[id1] - fn2[id2] ) )        

 N_eff =  n1*n2/ float(n1 + n2)              ;Effective # of data points
 PROB_KS, D, N_eff, prob                ;Compute significance of statistic

 return
 end
