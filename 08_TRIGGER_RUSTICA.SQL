CREATE OR REPLACE TRIGGER T_INS_RUSTIT
BEFORE INSERT ON RUS_TITULARES
FOR EACH ROW
DECLARE

	xREFERENCIA CHAR(10);

BEGIN

   SELECT GENRUSTIT.NEXTVAL INTO :NEW.ID FROM DUAL;

   UPDATE USUARIOSGT SET LAST_INT=:NEW.ID
   WHERE USUARIO=USER;
   
   xREFERENCIA:=:NEW.NIF;
   IF (xREFERENCIA IS NULL) THEN
   	xREFERENCIA:=:NEW.CLAVE_IDENTIFICACION;
   END IF;

   INSERTA_REFERENCIA_BANCO(:NEW.MUNICIPIO, :NEW.YEAR, NULL, :NEW.NIF,
   								 xREFERENCIA,NULL,NULL);

END;
/

/*********************************************************************************************************************/

CREATE OR REPLACE TRIGGER T_DEL_RUSTIT
BEFORE DELETE ON RUS_TITULARES
FOR EACH ROW
DECLARE
	xREFERENCIA CHAR(10);
BEGIN

	xREFERENCIA:=:OLD.NIF;
	IF (xREFERENCIA IS NULL) THEN
		xREFERENCIA:=:OLD.CLAVE_IDENTIFICACION;
	END IF;

	DELETE FROM REFERENCIAS_BANCOS 
	WHERE MUNICIPIO=:OLD.MUNICIPIO AND YEAR=:OLD.YEAR AND REF_RUSTICA=xREFERENCIA;

	DELETE FROM COTITULARES WHERE PROGRAMA='RUSTICA' AND ID_CONCEPTO=:OLD.ID;
	DELETE FROM HIS_CARGOREAL_RUS WHERE IDRUSTIT=:OLD.ID;
  
END;
/

/*********************************************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_RUSPAR
BEFORE INSERT ON RUS_PARCELAS
FOR EACH ROW
BEGIN
   SELECT GENRUSPAR.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/*********************************************************************************************************************
MODIFICACIÓN: 01/02/2005. Lucas Fernandez Pérez. Se añade un historico de 
modificaciones de domiciliaciones, HISTO_DOMICILIACIONES, que suplanta
a los campos USR_CHG CUENTA y F_CHG_ CUENTA de la tabla de IAE.
MODIFICACIÓN: 15/05/2006. M. Carmen Junco Gómez. Adaptación al nuevo formato de RUSTICA.
MODIFICACIÓN: 12/06/2006 Lucas Fernández Pérez. Controla el cambio de representante para 
					guardarlo en la tabla motivos_cambio_titularidad
**********************************************************************************************************************/
CREATE OR REPLACE TRIGGER T_UPDCUENTA_RUS
BEFORE UPDATE ON RUS_TITULARES
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
           (:NEW.DNI_TITULAR<>:OLD.DNI_TITULAR)) THEN
		
		SELECT TEXTO2 INTO xMOTIVO FROM USUARIOSGT WHERE USUARIO=USER;
		
      INSERT INTO HISTO_DOMICILIACIONES
      	(IDPROGRAMA, PROGRAMA, MOTIVO, DOMICILIADO, F_DOMICILIACION,
           NIF_TITULAR, ENTIDAD, SUCURSAL, DC, CUENTA)
      VALUES
      	(:OLD.ID, 'RUSTICA', xMOTIVO, :OLD.DOMICILIADO, :OLD.F_DOMICILIACION,
          :OLD.DNI_TITULAR, :OLD.ENTIDAD, :OLD.SUCURSAL, :OLD.DC, :OLD.CUENTA);
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
			(:NEW.ID,'RUSTICA',:OLD.REPRESENTANTE,'R',xTEXTO);
	END IF;

END;
/


/*********************************************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_RECIBOS_RUS
BEFORE INSERT ON RECIBOS_RUS
FOR EACH ROW
BEGIN
   SELECT GENRECIRUS.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/*********************************************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_RECIBOS_RUS_DESG
BEFORE INSERT ON RECIBOS_RUS_DESGLOSE
FOR EACH ROW
BEGIN
   SELECT GENRECIRUSDESG.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/


/********************************************************************/
COMMIT;
/********************************************************************/
