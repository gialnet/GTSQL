/*******************************************************************************
MODIFICACION: 02/02/2004. Gloria Maria Calle Hernandez. 
			  Eliminada llamada a ADD_TRIBUTOS_CONTRI, pues la tabla TributosContri sobre la cual
			  insertaba pasa a rellenarse como una tabla temporal y dicho procedimiento ha sido eliminado
MODIFICACION: 04/02/2004. Gloria Maria Calle Hernandez. 
			  Eliminada llamada a ADD_DOMI_CONTRI, pues la tabla DomiContri sobre la cual
			  insertaba pasa a rellenarse como una tabla temporal y dicho procedimiento ha sido eliminado
*******************************************************************************************/
CREATE OR REPLACE TRIGGER T_INS_RUS80
BEFORE INSERT ON RUS80
FOR EACH ROW

BEGIN

   SELECT GENRUS.NEXTVAL INTO :NEW.ID FROM DUAL;

   UPDATE USUARIOSGT SET LAST_INT=:NEW.ID
   WHERE USUARIO=USER;

   INSERTA_REFERENCIA_BANCO(:NEW.MUNICIPIO, :NEW.YEAR, NULL, :NEW.NIF,
		LTRIM(RTRIM(:NEW.NUM_FIJO))||LTRIM(RTRIM(:NEW.NIF)), NULL, NULL);

END;
/


/********************************************************************/
-- Modificado: 01/02/2005. Lucas Fernandez Pérez. Se añade un historico de 
--	modificaciones de domiciliaciones, HISTO_DOMICILIACIONES, que suplanta
--  a los campos USR_CHG CUENTA y F_CHG_ CUENTA de la tabla de IAE.
--
CREATE OR REPLACE TRIGGER T_UPDCUENTA_RUS
BEFORE UPDATE ON RUS80
FOR EACH ROW
DECLARE
  xMOTIVO  VARCHAR2(512);
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
          (:OLD.ID, 'RUSTICA', xMOTIVO, :OLD.DOMICILIADO, :OLD.F_DOMICILIACION,
           :OLD.DNI_FACTURA, :OLD.ENTIDAD, :OLD.SUCURSAL, :OLD.DC, :OLD.CUENTA);
	END IF;

END;
/


/**************************************************************************************************
MODIFICADO: 04/02/2004. Gloria Maria Calle Hernandez. 
			Eliminada llamada a BORRADOMI, pues la tabla DomiContri sobre la cual
			borraba pasa a rellenarse como una tabla temporal y dicho procedimiento ha sido eliminado
***************************************************************************************************/
CREATE OR REPLACE TRIGGER T_DEL_RUS80
BEFORE DELETE ON RUS80
FOR EACH ROW
BEGIN

	DELETE FROM REFERENCIAS_BANCOS WHERE MUNICIPIO=:OLD.MUNICIPIO 
			AND YEAR=:OLD.YEAR AND 
			LTRIM(RTRIM(REF_RUSTICA))=LTRIM(RTRIM(:OLD.NUM_FIJO))||
							  LTRIM(RTRIM(:OLD.NIF));

	DELETE FROM COTITULARES WHERE PROGRAMA='RUSTICA' AND ID_CONCEPTO=:OLD.ID;
	DELETE FROM HIS_CARGOREAL_RUS WHERE IDRUS80=:OLD.ID;
  
END;
/


/********************************************************************/
CREATE OR REPLACE TRIGGER T_INS_RUS81
BEFORE INSERT ON RUS81
FOR EACH ROW
BEGIN
   SELECT GENRUS81.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/


/********************************************************************************************/
CREATE OR REPLACE TRIGGER T_INS_RECIBOS_RUSTICA
BEFORE INSERT ON RECIBOS_RUSTICA
FOR EACH ROW
BEGIN
   SELECT GENRECIBOS_RUS.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/


/********************************************************************************************/
CREATE OR REPLACE TRIGGER T_INS_RUS_BONI
BEFORE INSERT ON BONI_EXEN_RUS
FOR EACH ROW
BEGIN
   SELECT GENRUSBONI.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************/
COMMIT;
/********************************************************************/
