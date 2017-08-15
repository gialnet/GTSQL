/********************************************************************************************
Autor: 18/09/2002 M. Carmen Junco Gómez. Genera el siguiente código de tarifa para un concepto
	 y ayuntamiento.
********************************************************************************************/

CREATE OR REPLACE TRIGGER ADD_TAR_CONCEPTOS                 
BEFORE INSERT ON TARIFAS_CONCEPTOS
FOR EACH ROW
DECLARE
	MAXIMO CHAR(4);
BEGIN

	SELECT MAX(COD_TARIFA) INTO MAXIMO FROM TARIFAS_CONCEPTOS
	WHERE CONCEPTO=:NEW.CONCEPTO AND AYTO=:NEW.AYTO;
      
      IF (MAXIMO IS NULL) THEN
         MAXIMO:='0000';
      END IF;

	:NEW.COD_TARIFA:=LPAD(TO_NUMBER(maximo)+1, 4, '0');

END;
/


CREATE OR REPLACE TRIGGER T_DOCS_GESTION
BEFORE INSERT ON DOCS_GESTION
FOR EACH ROW
BEGIN
   IF (:NEW.AYTO IS NOT NULL) THEN
   	  SELECT GEN_DOCSGESTION.NEXTVAL INTO :NEW.ID FROM DUAL;
   END IF;
END;
/