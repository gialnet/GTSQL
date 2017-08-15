/*******************************************************************************************
MODIFICADO: 02/02/2004. Gloria Maria Calle Hernandez. 
			Eliminada llamada a ADD_TRIBUTOS_CONTRI, pues la tabla TributosContri sobre la cual
			insertaba pasa a rellenarse como una tabla temporal y dicho procedimiento ha sido eliminado
MODIFICADO: 04/02/2004. Gloria Maria Calle Hernandez. 
			Eliminada llamada a ADD_DOMI_CONTRI, pues la tabla DomiContri sobre la cual
			insertaba pasa a rellenarse como una tabla temporal y dicho procedimiento ha sido eliminado
*******************************************************************************************/
CREATE OR REPLACE TRIGGER T_INS_IBI
BEFORE INSERT ON IBI
FOR EACH ROW
BEGIN

	SELECT GENIBI.NEXTVAL INTO :NEW.ID FROM DUAL;
	UPDATE USUARIOSGT SET LAST_INT=:NEW.ID WHERE USUARIO=USER;

	-- ASIGNARLE A ESTA REFERENCIA CATASTRAL UN NUMERO DE RECIBO UNICO
	INSERTA_REFERENCIA_BANCO(:NEW.MUNICIPIO, :NEW.YEAR, NULL, :NEW.NIF, NULL,
		:NEW.REF_CATASTRAL||:NEW.NUMERO_SECUENCIAL||:NEW.PRIMER_CARACTER_CONTROL||
		:NEW.SEGUN_CARACTER_CONTROL, NULL);

END;
/


/********************************************************************/
-- Modificado: 01/02/2005. Lucas Fernandez Pérez. Se añade un historico de 
--	modificaciones de domiciliaciones, HISTO_DOMICILIACIONES, que suplanta
--  a los campos USR_CHG CUENTA y F_CHG_ CUENTA de la tabla de IAE.
-- Modificado: 12/06/2006 Lucas Fernández Pérez. 
-- Controla el cambio de representante para guardarlo en la tabla motivos_cambio_titularidad
--
CREATE OR REPLACE TRIGGER T_UPDCUENTA_IBI
BEFORE UPDATE ON IBI
FOR EACH ROW
DECLARE
  xMOTIVO  VARCHAR2(512);
  xTEXTO	  VARCHAR2(512);
BEGIN

	-- si ha habido algún cambio en los datos de domiciliación, indicar el usuario que 
	-- lo realiza y la fecha
	IF ((:NEW.DOMICILIADO<>:OLD.DOMICILIADO) OR (trunc(:NEW.F_DOMICILIACION,'dd')<>trunc(:OLD.F_DOMICILIACION,'dd')) OR 
   	       (:NEW.ENTIDAD<>:OLD.ENTIDAD) OR (:NEW.SUCURSAL<>:OLD.SUCURSAL) OR 
           (:NEW.DC<>:OLD.DC) OR (:NEW.CUENTA<>:OLD.CUENTA) OR 
           (:NEW.DNI_FACTURA<>:OLD.DNI_FACTURA)) THEN
		
        SELECT TEXTO2 INTO xMOTIVO FROM USUARIOSGT WHERE USUARIO=USER;
		
        INSERT INTO HISTO_DOMICILIACIONES
          (IDPROGRAMA, PROGRAMA, MOTIVO, DOMICILIADO, F_DOMICILIACION,
           NIF_TITULAR, ENTIDAD, SUCURSAL, DC, CUENTA)
        VALUES
          (:OLD.ID, 'IBI',xMOTIVO, :OLD.DOMICILIADO, :OLD.F_DOMICILIACION,
           :OLD.DNI_FACTURA, :OLD.ENTIDAD, :OLD.SUCURSAL, :OLD.DC, :OLD.CUENTA);
	END IF;
	
	-- cambio del representante
	IF (:NEW.REPRESENTANTE<>:OLD.REPRESENTANTE)
		OR (:NEW.REPRESENTANTE IS NULL AND :OLD.REPRESENTANTE IS NOT NULL)
		OR (:NEW.REPRESENTANTE IS NOT NULL AND :OLD.REPRESENTANTE IS NULL)
		THEN
		SELECT TEXTO INTO xTEXTO FROM USUARIOSGT WHERE USUARIO=USER;
		INSERT INTO MOTIVOS_CAMBIO_TITULARIDAD
			(IDCAMBIO,PROGRAMA,NIF,TIPO_TITULAR,MOTIVO)
		VALUES
			(:NEW.ID,'IBI',:OLD.REPRESENTANTE,'R',xTEXTO);
	END IF;
	
END;
/


/***************************************************************************************************
MODIFICADO: 04/02/2004. Gloria Maria Calle Hernandez. 
			Eliminada llamada a BORRADOMI, pues la tabla DomiContri sobre la cual
			borraba pasa a rellenarse como una tabla temporal y dicho procedimiento ha sido eliminado
***************************************************************************************************/
CREATE OR REPLACE TRIGGER T_DEL_IBI
BEFORE DELETE ON IBI
FOR EACH ROW
BEGIN

	DELETE FROM REFERENCIAS_BANCOS WHERE MUNICIPIO=:OLD.MUNICIPIO AND YEAR=:OLD.YEAR
	AND REF_CATASTRAL=:OLD.REF_CATASTRAL||:OLD.NUMERO_SECUENCIAL||
	 	:OLD.PRIMER_CARACTER_CONTROL||:OLD.SEGUN_CARACTER_CONTROL;

	DELETE FROM COTITULARES WHERE PROGRAMA='IBI' AND ID_CONCEPTO=:OLD.ID;

END;
/



/********************************************************************************************/
CREATE OR REPLACE TRIGGER T_INS_RECIBOS_IBI
BEFORE INSERT ON RECIBOS_IBI
FOR EACH ROW
BEGIN
   SELECT GENRECIBOS_IBI.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/



/********************************************************************************************/
CREATE OR REPLACE TRIGGER ADD_IBI_DOCDGC
BEFORE INSERT ON IBI_DOCDGC
FOR EACH ROW 
BEGIN
	SELECT ID_IBI_DOCDGC.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/


