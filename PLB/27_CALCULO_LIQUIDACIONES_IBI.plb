/*******************************************************************************************/
/*******************************************************************************************/
/***				CÁLCULO DE LIQUIDACIONES DE AÑOS ATRASADOS			     ***/
/*******************************************************************************************/
/*******************************************************************************************/
/*******************************************************************************************
autor: M. Carmen Junco Gómez. 01/02/2002
Función: Actualiza las posibles bonificaciones de los años incluidos en la tabla temporal.
*******************************************************************************************/
CREATE OR REPLACE PROCEDURE ACTUALIZAR_BONIFICACIONES wrapped 
a000000
b2
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
7
5d7 2bd
b/6DBpAMpcKcbo6taGoQYKCaKLYwg/CJBUiMfC9AEvYkApY1wBohgwovxa18IafdYGGzwu3u
c5pRIvufoZgNieMwi09qeIRgbP0RSURGKsngALVwJ74Mr9oZS0AM+0Xd59difW8vH01CfOn3
mCN8ebQjXODof1IX+VtZqPF2F5b5iVygsLPMsQzJ5aK+uK8Q+31tfqZzlZ8+1YnF7UNYVn9x
CR19oFkVAje/af/7mu6QmYpxKtJQBOCOLBg31wIMXKf/k0A0Gl7AyskEH8mO6yWnQsHbobUi
3awu+BDathujZSn0PtEe9MSUy0E0WwmON047MzcMu7rOFxJDQgVH/52cwHQQyGkpPKJWeC7y
guL1C+leGvVEAl4cZSwf14Civ7khEyiQ0LO8Y47/IFQ6mtEBjwuzvgDWvjezVPtguhY1RnGj
ybQl+voYX+0V+AnJLkwexwLz59oYU9xGv75tYgFtj53YhPcDynjABIMjwaSX2ONLP7GSgQmo
RuYs7SJATHjuvjOJzGTLOPy1Y5qLoN6v7YOzI0rEYagZOntzu96gke58DLJAMDhWaCQSNXXN
0NZoYAOC+aguexN7mmlJ6QiG/7bs+OyDh7P8dfHYTnncVd8OvQWEbgBAqlu8F6ntxWT8K/hV
k/NVZmaOxqn3nVNA5LCxpnKIVU/mAlVmnc/h8fIPww==

/
/*******************************************************************************************
autor: M. Carmen Junco Gómez. 01/02/2002
Función: Procedimiento que inserta en una tabla temporal los datos del recibo para los años
         dentro del intervalo. 
         Se utilizará en el caso de estar liquidando recibos de I.B.I. 
MODIFICADO: 17/05/04. Gloria Maria Calle Hernandez. Cambiado MAX_VALOR_CATASTRAL por MAX_CUOTA
			y añadido CLAVE de bien inmueble (para bienes de caracteristicas especiales).
Modificado: 29/03/2005. Gloria Maria Calle Hernandez. Se tomaba como Año Hasta el año del IBI 
		 del ID dado, y a veces puede ser menor que el hasta. Ahora toma el Año Hasta que es pasado 
		 como parámetro.
Modificacion: 31/03/2005. Gloria Maria Calle Hernandez. Se toma como año hasta el mayor comparandolo
		 con el año del registro minimo para poder realizar los calculos. Antes desde delphi se controlaba
		 que finalmente solo se realizara la liquidacion de los años desde - hasta. Ahora desde el 
		 procedimiento LIQUIDAR_ATRASOS se borran los años incluidos en la tabla tmp_Atrasos que no 
		 se quieren liquidar, si es que hay alguno. (Incluídos sólo por los cálculos).
Modificacion: 17/05/2005. Gloria Maria Calle Hernandez. Se toma como año min (desde) el menor comparandolo
		 con el año del registro y el año de prorrateo si tiene. El año max (hasta) se compara con ambos tb 
		 tomando siempre como max el mayor.
*******************************************************************************************/
CREATE OR REPLACE PROCEDURE RELLENAR_TMP_ATRASOS_IBI wrapped 
a000000
b2
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
7
dc8 5a7
L5jq5PwugQhwv+TDa7ubIwqh1uQwgzvq10oFV3QZCk6ORWwZMtZiYQdRJh9pfnuMFfc08W7J
Iwj4nZUJiZE6v6N0J1lwWGY+m++BoeveXDVV9nCrg28Usdbtvx3E7P0BOVKUsISnAa7MF1jI
zhfuOUXKk7LoOUk7hzAv7bgLOhbmvaEPNx5I4hb4mLfs9Ovk3dc3fzNdZCtry8uIk275+pYh
7lZl/sjSXj/6YAiQJP7JuAKBX0DJTVOVuCog3j7+yP/GrjitX/Ogq3TDAIXypZ/llI17YmmZ
EN6Hk3hpJSc9Oeo1+t07nPaQvtPReCEGE+zJ+a2dj3XoCqckygHTO0jsJM6kkUsno5U7T/PC
JamCKzvBjyllCZnVKNeM/GaSXrf2mNPavnCTjgd7IzKc72SNh0c6cSezqdSF3Vm3Mj6k5kW5
6oGDFtfFfuYbdIJQ5gExT9iz/P9pMIXUFX8zc0QAwhKW6Wx7a/L8ZtQB18lj0cGNJEvwxog7
Jw9IoGrigdxeiRJVwAQ19TwFVQm5MrM4Jx57QUyvP1vIR7tp8esrcPKxqetkh7IX1aLknnio
vc6r82GPCExLZ93EeACx40iWJw8KaYnz/hVC0ckEH9WPGKQEGO10vVR+qEP6aw5+GEI+bTI3
GAA0baRWc+Ytneb/UdFPf0yzS7ewA2QcaG4xH8gt82buzz5zS4ztpjuIzT/6VqOvfkB0c45v
wyGcU66FrX+76p38p7/5aMsn4P5hMWUWJISLAw5oU695bRIrBhkSqWC2CjnY/5TSPsmJT3IM
qKqL/1Nc5Zk1Rh8yfVnxe5abD/d9SDDDRHv95YeTHIPJwxNQ4H8lyrmdj40nLI1MhihFeIrU
vD5fqePjPnZutrNoJXWf7FeYkWlZEkeV/RAXJAuMv2VyEgTBTKIDkbpZTD0QCpfvZsd0MSDM
uN02iBKrA1frWN/S1GtahsqqpSspRtmdUy88Tn+e0f/zczR4MCtQk8VdIaL6GqsnIaurPYwL
mhkpUKUQDeAImoOTMWj+yao7cve47GKzVRU87wyEbQ0i80q+2nwBmnsawkSi7qC0r0kLGRVM
JeBuD5edlqHsJRS+tkBYdfUlSaNT28X63VHeLAecyDmgganRKEG2UhBFf479Mj4Gl0LS46R3
1jhJzHZDLc6h95vZycPin0rv6Xtp9CTrN4NzKoeRJM900lgBEAd1FcXzHadjIZeMreIoPaHp
JsbvJkArv09KHOsA+n/N1mgLSesu3hPmah7wUCW5xfruwLZvB2mLLaFSMHmVqgTfnWEv2OJo
3cga9QXQshXi8hhgw2g3HIFJUb7C1jgvCXTcbBFykceB2nVjM8Og7hIpvwXBFU/4R1FKwTOl
7qVCjA7eqLWWhVTZaQ5Us86Euc1C1T9G3WZgcNz5G4+WNbRFSLpzCCRC2Sre

/
/*******************************************************************************************
autor: M. Carmen Junco Gómez. 01/02/2002
Función: Procedimiento que calcula el total a pagar por un año dependiendo del gravamen
         para ese año y de las posibles bonificaciones.
         Parámetros: xYEAR:  año para el cual se quiere calcular el total a pagar.				         		         
MODIFICACIÓN: 11/12/2002 M. Carmen Junco Gómez. La bonificación se ha de aplicar a cada
	   año independientemente de si en el año actual ésta ha caducado o no.
MODIFICADO: 17/05/04. Gloria Maria Calle Hernandez. Cambiado MAX_VALOR_CATASTRAL por MAX_CUOTA.
*******************************************************************************************/
CREATE OR REPLACE PROCEDURE CALCULAR_TOTAL_YEAR_LIQUI_IBI wrapped 
a000000
b2
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
7
32e 203
jj5JoR0mOtDWGz5oGbmERgiepa8wgwEJDEjWfC/Nb0/gp8h7npGT8mOvdPRsxtzwoeuU/p3p
eba86cIhPzxH+HS/9jYq7WwvTaJkUMv/V8NqljoJ+ruHy8KnPh2pF93TJrZS6RN/imbOL6Hx
oJcO1YbtKwUSdsQ10W8sMO/t1H2ho1oDryeMAdVEOXYrzvB7/NMPN3dK0ZEMK+vpJ2+Haila
97ilL31Lx2+UZIy3Ofbpz1HBtkkPtghXEOcv/YhZpYXtliLVwQOHvMz6gHlrLQ2LObmfLFCZ
fVkfCXTOco3PtBCxjI3om+ymMh2oMcWLusJsDdCXAxU4oYrDXUKtBYliGilAtdVyBlP1d+5k
iFPV3s7+LSZ1deQaVJAYx58wAXRbYbsMbYanZVqXetfafhsalTpXy/rCUyqbwpH9lw0k9iNV
NJLOrbo0LvnUsHKtu7MoBfRyv44t7Z14fRGdHbXHV+N5PbTtVgGT5nRSDe9k2SiWmvmmL3id
Pw==

/
/*******************************************************************************************
autor: M. Carmen Junco Gómez. 19/09/2002
Función: Procedimiento que calcula el VC y la BL de una año teniendo en cuenta el VC y la
	   BL del año posterior y el % de incremento definido en la tabla de gravámenes		
	   Parámetros: xYEAR: año para el cual se va a calcular el VC y la BL			   
Modificacion: 14/04/2005. Gloria María Calle Hernandez. Sólo actualizará el VCatastral y BLiquidable
		si y sólo si estos son valores nulos. Si tienen valor de un IBI ya cargado en nuestra base de
		datos lo respetará.
Modificacion: 10/05/2005. Gloria María Calle Hernandez. Sólo actualizará el VCatastral y BLiquidable
		si y sólo si estos son valores nulos O SON CERO.
*******************************************************************************************/
CREATE OR REPLACE PROCEDURE CALCULO_BLIQUIDABLE_INCREMENTO wrapped 
a000000
b2
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
7
241 181
B3sNKkPwPH7m8KDswHyhYgcBL3IwgxBp2UhGyo7NK50G0Q2ECbDZqx/qU+uoNXWbuIqXtbVt
4Z9m3OzxdcjvwUIDQLfnp6mMBjVYMsOb1Vo3jFFcJ0jeZs0uA8+2g/L8GA+zYSpFq6anWK5T
wwgrTIk1mhe4w6qpmHf7Qa1dnID58/0pXvzSwQitCdsAR3YAeyDMLWYh1W4lC1jRumlh6QsB
dW0qts4pYeCOwNQ7wIn0n50JdmxTqSvsqCcdJ/veRqiuUnv+0FfM5AtLGxGzIROzHr4eg8To
pa1sRu3EEIG6UhddWbV8/NvneDdBQdbUbJeIQH3//MUchbBUAePfEjvtYEiBaMIxbDV7UDU+
fGEh/AlWJVGqOvtEWm3y

/
/*******************************************************************************************
autor: M. Carmen Junco Gómez. 01/02/2002
Función: Procedimiento que calcula el incremento por año de la BL cuando se calcula por prorrateo
	   Parámetros: xYEARP: año de la última ponencia
			   xNUMYEARS: nº de años de prorrateo			   
	   la fórmula que se aplica es la siguiente: 
					   BL2002 - VC2002*(2002-YEARP+1/xNumYears)  
				BL2001= -----------------------------------
						1 - (2002-YEARP+1/xNumYears)
			donde 2000 es el año de la última ponencia, p.e.
			    xINCPRORRATEO: incremento por año
			    xBLP	     : base liquidable del año de ponencia
Modificacion: 14/04/2005. Gloria María Calle Hernandez. Sólo actualizará el VCatastral y BLiquidable
		si y sólo si estos son valores nulos. Si tienen valor de un IBI ya cargado en nuestra base de
		datos lo respetará.
Modificacion: 10/05/2005. Gloria María Calle Hernandez. Sólo actualizará el VCatastral y BLiquidable
		si y sólo si estos son valores nulos O SON CERO.
*******************************************************************************************/
CREATE OR REPLACE PROCEDURE CALCULO_INCREMENTO_PRORRATEO wrapped 
a000000
b2
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
7
408 270
0Y7TbW9oSDwAOHXqnt6IXeEPNSwwgwIJ2UiGfHRoCuSUNFwZ6E1eiiY3mYVlVefIbDscMTOJ
tbVtYxRJn8L732fK9lrLgIR7IGxK+u9aawElM9hf0leM9DOKNIGHoqBuLUAtZCCOGX/UiTib
FuTRCxvXiMtEXBsGSTymCHEeWC73LoMYVOZJWJPnHamUpNKkg99mIfU+EIhdp+TqEhZQDpMu
5bG3NL7LZo9EqaxX7mPTI53Xo0vEmd+PsGUuy0R3Fu+iZMkibZZBRKBiUE5+XF5aSSAX4wPa
bX3pS+7YOVzhqkpaQEonUdZ2vXNeMOE4YFeh8+kOfnOzlMoCFDTCEAmGa/X/qio9G4m20BFl
oCejPp/WK50maXSrH96RikrYk8UcKbrmXDhIJbH+eo4DffrGwIcQz7vHgs69buqsnOUxr4KK
ujACHuB3N3lz6IM1wayZMSrvcs3t/t9Y92SGQkS8sNK1vye/IM3tmxMANLi2XCu1Cdph0l+N
RgT+TOpYtPKEBVgyXpJOskNrOPrw0oFyGzZo3ArOjf5uP9vEWEyfaiqKPxS5PxtD/+pgaftZ
JavYmjMpb5lpW8+KNerkYOBetkMlxu7GDyvKCGQ=

/
/*******************************************************************************************
autor: M. Carmen Junco Gómez. 19/09/2002
Función: Procedimiento que calcula la BL de un año con prorrateo partiendo de 
	   la BL del año de ponencia y el valor de incremento anual.
	   Parámetros: xYEAR: año para el cual calculamos el VC y la BL
			   xYEARP: año de la ponencia
			   xVCP: valor catastral del año de ponencia
			   xBLP: base liquidable del año de ponencia			
			   xINCPRORRATEO: incremento anual por prorrateo		   	   
Modificacion: 14/04/2005. Gloria María Calle Hernandez. Sólo actualizará el VCatastral y BLiquidable
		si y sólo si estos son valores nulos. Si tienen valor de un IBI ya cargado en nuestra base de
		datos lo respetará.
Modificacion: 10/05/2005. Gloria María Calle Hernandez. Sólo actualizará el VCatastral y BLiquidable
		si y sólo si estos son valores nulos O SON CERO.
*******************************************************************************************/
CREATE OR REPLACE PROCEDURE CALCULO_BLIQUIDABLE_PRORRATEO wrapped 
a000000
b2
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
7
163 130
7S3kZVo5ktNVUcldrXRRvXG5pj0wg3nIs9yEqHRA7QKwfWx9WV/E2b4WaUy2NlZLvgpO+SB/
V21IYBKxZKGd+WLxAALRNhyMu39k0ZsXwanRJaMUbXCMfqAJDxfm+0QOjkmlW4lVeGKqfbMf
Ku5wIH8LBQ5ttWfc+YDH/ZPwXNojwRr7Dpx81FAilxguS4tFwgtNd499LTikfNFee+pKRZkt
Wrk+dT6qZZ1+0Mna+Tqrr4NVCpDC6zfU2hu64vd/RH0NjLiH1CU7eHiWuAJ3C0ZW/rE0tO3o
jjMoH6euKwA=

/
/*******************************************************************************************
autor: M. Carmen Junco Gómez. 01/02/2002
Función: Procedimiento que calcula el valor catastral y la base liquidable para los años
         dentro del intervalo de la liquidación; actualiza los datos de la tabla temporal 
         rellenada por el procedimiento RELLENAR_TMP_ATRASOS_IBI.
         Parámetros:
		xYEARP: Año de la ponencia		
		xDESDE: Límite inferior del intervalo de años
		xANIOS: nº de años que pasan desde una ponencia a otra
         Se considera que la Base Liquidable y el Valor Catastral del mayor año 
	  (que es desde el que partimos como referencia) son correctos. 
         A partir de ellos se calcularán el resto de bases liquidables de los años que se van
         a liquidar.
	   Para años que no entran en el prorrateo la fórmula será:
			VC2002=(VC2003*100)/(Incremento+100);
			BL2002=(BL2003*100)/(Incremento+100);
			TOTAL=BL * GRAVAMEN/100 - BONIFICACIONES
	   Para años que entran en el prorrateo la fórmula será:
				BL2002 - VC2002*(2002-YEARP+1/xAnios)  
			BL2001=---------------------------------
						1 - (2002-YEARP+1/xAnios)
			donde 2002 es el año de la última ponencia, p.e.
			BL2003=BL2002+xINCPRORRATEO;
			TOTAL=BL * GRAVAMEN/100 - BONIFICACIONES
Modificacion: 31/03/2005. Gloria Maria Calle Hernandez. Antes desde delphi se controlaba
		 que finalmente solo se realizara la liquidacion de los años desde - hasta aunque para los 
		 cálculos se incluyeran alguno más. Ahora desde el procedimiento LIQUIDAR_ATRASOS se borran 
		 los años incluidos en los que se quiere liquidar si es que hay alguno.		 
*******************************************************************************************/
CREATE OR REPLACE PROCEDURE LIQUIDAR_ATRASOS_IBI wrapped 
a000000
b2
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
7
7c7 34f
HdT1IFetBR4QZBBnwlSE8TKD2tMwgztcBUoTfC/NCjoYQrppMRG2gSaJ8jlA8GzG6GGh67yl
tarMD1ME5pgxXGMvpS3BR85fF2g+kwvr1Tb/P9LYaycOYMxigd3Fp9PxL+ZIsvw5vbYaIl6N
En1ZDWv2fR8JPdcviHkmcAnaib3WZE3CRvxGFKa4mFAFj180NZJs1eGX28ujCP/CDXEJXrQt
xuKBrK2pMbOX4/RFXgk+J2kVwrnobJztDurkAOmUpUANTVBmkudBfXWUS1itYoLIU75F6qPF
TRBQq3U58Hb2HUh0O/EffJzRp5Q/QWKI0kWwGPoll4dXDfGeD1ha3/M/Yg+e0L4Xkd8YTAkK
h/xxkYi0LoXp/4AQGfNlLah2ggh87o7oEqMKvQOiDqUY8u8EreP5CWvyFwaKuOOzf/mKOn3n
U4mQEhIi4aHS/YyH8WU5dsEglsn2q1GfSPI5wyEesnrmECNGkk4ISmin1kzbo1rrV1CboSQB
P1J0T3puN62MyoyeuUbECLMWD+Q0AaQB7CInlx5B2a9BqgIfDBYHvsslabBCFkfPXO++1SZo
PaOLoKbCABjG4NI334c83Iz6Dyrf9xgLXchDt9n0EM0qjgquVsBzU2fgbxF6wPfn7qqW4um3
iQGVNCOaAzDvKsfg8arJfaoXi2RCWCVl6eu/8A281UzwOeIqKmEH1ZcMgPg0n3iCyFqYkAKv
zbrpgdFSwaC87wezvFWw9qRv3AaH9aQFA3V7gejGNiQz+YIlabmcdBljnefWga/EsPAT+qEL
2sZKPL95Jbsx8xCZ/icIqIa77jnR0/1aCCkou0iaUw==

/
/*******************************************************************************************
autor: Gloria Maria Calle Hernandez. 02/03/2005.
Función: Procedimiento que verifica si los gravamenes y % están definidos para cada año 
		 y si tiene el ayuntamiento valores de ultima revision catastral, devolviendo el motivo 
		 del error o warning en su caso para poder visualizarlo desde Delphi.
*******************************************************************************************/
CREATE OR REPLACE FUNCTION VALIDAR_PARAMS_AYTO_IBI wrapped 
a000000
b2
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
8
3c4 299
w4kRXaFkDm820zbe67KyDHfMpsEwgzJeNUoFfHSKPT9ElgK2yhYYUe0hhTctKaKpVquJiblB
5PfPwKrDCcLrNn2XqWJtavMXFvCt0vpSqf0jeA5Wgp7cUq/+223a2rQNLk7JqvDLH+z98qrp
OlJLgfS3mI3nwTa6EZqeY1b7/0dBfKAEBTmmSBmVRkAZyJgPmv7XZ+/JT8qRu9CUztwWTpml
wT+yAnqToCu3febAfnL1UmtVlzoQg038gsLD1OfR3dHxsCI3Yt0WejXsi0S3cF0RGLpNhHhL
ck/VvVz1j9JHfE2rH4dN0ax4bhYEcmatIlKNCI8TwLjtE6RPGMSpOKn0B4o6d95IxJrWF0E9
hifsJ+W3+O3WuT9kI7wxujLxyf1xsEhxN4/gPrTYqfVjaYr4F8wX8DzY585rlobPfi8EZq+U
NwZZ7f1M0B0k2zW4pZQ5wm7mJxV7MuZajMXofLcHUVk16eB5miN8YNL3PBVVMH6xK4ixg9mL
Ji5txnWnWB0CGe5rWg/JOPNZ24PTVegcWGqfeifaOVnYnqIp+faYXKU8634fDuDDdpbsQNmF
k20K1Ca8SYY5e7dIe03VCZE/S77u89KOmL04CncrgaMtaeR3tmOHAKHx6gzlLJbZyXdJeNLO
Q5bLOvzw

/
