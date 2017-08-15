/*******************************************************************************
CREADO: 01/09/2004. Gloria Maria Calle Hernandez. 
	    Incrementa secuencia ID - llave primaria- de la tabla Plusva_Notarias
*******************************************************************************************/
CREATE OR REPLACE TRIGGER ADD_NOTARIAS
BEFORE INSERT ON NOTARIAS
FOR EACH ROW
BEGIN
	SELECT ID_NOTARIAS.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/*******************************************************************************
CREADO: 01/09/2004. Gloria Maria Calle Hernandez. 
	    Incrementa secuencia ID - llave primaria- de la tabla Notarias_Detalle
*******************************************************************************************/
CREATE OR REPLACE TRIGGER ADD_NOTARIAS_DETALLE
BEFORE INSERT ON NOTARIAS_DETALLE
FOR EACH ROW
BEGIN
	SELECT ID_NOTARIAS_DETALLE.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/
