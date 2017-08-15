
CREATE OR REPLACE TRIGGER T_INS_COTITULARES
BEFORE INSERT ON COTITULARES
FOR EACH ROW
BEGIN

	SELECT GENCOTITULARES.NEXTVAL INTO :NEW.ID FROM DUAL;

END;
/

CREATE OR REPLACE TRIGGER INS_COTITULARESRECIBO
BEFORE INSERT ON COTITULARES_RECIBO
FOR EACH ROW
BEGIN

	SELECT GEN_REC_COTITULARES.NEXTVAL INTO :NEW.ID FROM DUAL;

END;
/




/********************************************************************************************/
CREATE OR REPLACE TRIGGER T_VEHI_TRAFICO
BEFORE INSERT ON VEHICULOS_TRAFICO
FOR EACH ROW

BEGIN
   SELECT GEN_ID_VEHITRAFICO.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/


/********************************************************************************************/
CREATE OR REPLACE TRIGGER T_COD_POSTALES
BEFORE INSERT ON CODIGOS_POSTALES
FOR EACH ROW

BEGIN
   SELECT GEN_CODIGOS_POSTALES.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/
CREATE OR REPLACE TRIGGER T_REFERENCIA_BANCO
BEFORE INSERT ON REFERENCIAS_BANCOS
FOR EACH ROW

BEGIN
   SELECT ID_REFERENCIAS_BANCOS.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_HISTORIA_LIQUI
BEFORE INSERT ON HISTORIA_LIQUI
FOR EACH ROW

BEGIN
  SELECT GENHISTO.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_PLUSVALIAS
BEFORE INSERT ON PLUSVALIAS
FOR EACH ROW

BEGIN
  SELECT GENPLUSVAL.NEXTVAL INTO :NEW.ID FROM DUAL;
  UPDATE USUARIOSGT SET LAST_PLUSVALIA=:NEW.ID 
  WHERE USUARIO=USER; 
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_REQUERIR_PLUSVA
BEFORE INSERT ON REQUERIR_PLUSVA
FOR EACH ROW

BEGIN
    SELECT GENREPLU.NEXTVAL INTO :NEW.ID FROM DUAL;
    UPDATE USUARIOSGT SET LAST_INT=:NEW.ID 
    WHERE USUARIO=USER;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_BONI_EXEN
BEFORE INSERT ON BONI_EXEN
FOR EACH ROW

BEGIN
   SELECT GENBONI_EXEN.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/


/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_DEPARTAMENTO
BEFORE INSERT ON DEPARTAMENTO
FOR EACH ROW

BEGIN
   SELECT GENDEPAR.NEXTVAL INTO :NEW.DEPARTAMENTO FROM DUAL;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_CARACTER_DOCUMENTO
BEFORE INSERT ON CARACTER_DOCUMENTO
FOR EACH ROW

BEGIN
   SELECT GENCARA.NEXTVAL INTO :NEW.EMISOR FROM DUAL;
END;
/


/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_RECIBOS
BEFORE INSERT ON RECIBOS
FOR EACH ROW

BEGIN
   SELECT GENIDREC.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_LINEASPLA
BEFORE INSERT ON LINEASPLA
FOR EACH ROW

BEGIN
   SELECT GEN_LINEASPLA.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/  

/*********************************************************************************************/

/* CONTADOR ARTICULOS */

CREATE OR REPLACE TRIGGER SET_SANCION
BEFORE INSERT ON SANCION
FOR EACH ROW

BEGIN
    SELECT GENSANCION.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/*********************************************************************************************/

/* CONTADOR LEYES */

CREATE OR REPLACE TRIGGER SET_LEYES
BEFORE INSERT ON LEYES_SANCIONES
FOR EACH ROW

BEGIN
    SELECT GENLEYES.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/*********************************************************************************************/


/* TIPOS DE DENUNCIAS */

CREATE OR REPLACE TRIGGER SET_TIPOS_DENUNCIAS
BEFORE INSERT ON TIPOS_DENUNCIAS
FOR EACH ROW

BEGIN
    SELECT GENTIPODEN.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/*********************************************************************************************/

/* CONTADOR ESTADO */

CREATE OR REPLACE TRIGGER SET_ESTADO 
BEFORE INSERT ON ESTADO
FOR EACH ROW

BEGIN
   SELECT GENESTADO.NEXTVAL INTO :NEW.ID FROM DUAL; 
END;
/

/*********************************************************************************************/

/* CONTADOR ENTREGA_DENUNCIA */

CREATE OR REPLACE TRIGGER SET_ENTREGA_DENUNCIA
BEFORE INSERT ON ENTREGA_DENUNCIA
FOR EACH ROW

BEGIN
   SELECT GENENTREGA.NEXTVAL INTO :NEW.CODIGO FROM DUAL; 
END;
/



/********************************************************************/

CREATE OR REPLACE TRIGGER T_INS_DOCUMULTA
BEFORE INSERT ON DOCMULTA
FOR EACH ROW

BEGIN
   SELECT GENDOCUMULTA.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************/
CREATE OR REPLACE TRIGGER T_INS_NOTARIO
BEFORE INSERT ON NOTARIOS
FOR EACH ROW

BEGIN
   SELECT GENNOTARIO.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************/


/* 					TRIGGERS VARPAD 						*/




CREATE OR REPLACE TRIGGER ADD_VARPAD
BEFORE INSERT ON VARPAD
FOR EACH ROW 
BEGIN
	SELECT ID_VARPAD.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_USUARIOSGT
BEFORE INSERT ON USUARIOSGT
FOR EACH ROW

BEGIN
  SELECT GEN_ID_USUARIOSGT.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_ADD_EPIGRAFE
BEFORE INSERT ON EPIGRAFE
FOR EACH ROW

BEGIN
   SELECT GEN_EPIGRAFE.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/*******************************************************************************
AUTOR: Mª del Carmen Junco Gómez.
FECHA: 19/11/2001
ACCIÓN: Si una plusvalía se modifica para quitarle los cotitulares, habrá que 
	  borrar estos de la tabla COTITULARES.
*******************************************************************************/

CREATE OR REPLACE TRIGGER T_UPD_PLUSVALIAS
BEFORE UPDATE ON PLUSVALIAS
FOR EACH ROW
DECLARE
   CURSOR CCOTITULARES IS SELECT ID FROM COTITULARES 
				  WHERE PROGRAMA='PLUSVALIAS' AND ID_CONCEPTO=:NEW.ID;
BEGIN

   -- si se modifica la liquidación y se quitan los cotitulares,
   -- se han de borrar de la tabla COTITULARES; 
   IF ((:NEW.COTITULARES<>:OLD.COTITULARES) AND (:NEW.COTITULARES='N')) THEN
      FOR v_COTI IN CCOTITULARES 
	LOOP		
	   DELETE FROM COTITULARES WHERE ID=v_COTI.ID;          
      END LOOP;	
   END IF;

END;
/


CREATE OR REPLACE TRIGGER T_INS_LOGSPADRONES
BEFORE INSERT ON LOGSPADRONES
FOR EACH ROW
BEGIN

	SELECT GENLOGSPADRONES.NEXTVAL INTO :NEW.ID FROM DUAL;

END;
/


CREATE OR REPLACE TRIGGER T_INS_AVISOSGT
BEFORE INSERT ON AVISOSGT
FOR EACH ROW
BEGIN

	SELECT GENAVISOSGT.NEXTVAL INTO :NEW.ID FROM DUAL;

END;
/



CREATE OR REPLACE TRIGGER T_INS_HIS_CARGOREAL_IBI
BEFORE INSERT ON HIS_CARGOREAL_IBI
FOR EACH ROW
BEGIN

	SELECT GENCARGOREAL_IBI.NEXTVAL INTO :NEW.ID FROM DUAL;

END;
/

/**********************************************************************************************
Autor: 31/01/2005 M. Carmen Junco Gómez. 
Acción: Genera el siguiente ID para la tabla de motivos de cambio de titularidad.
***********************************************************************************************/

CREATE OR REPLACE TRIGGER T_MOTIVOS_C_TIT
BEFORE INSERT ON MOTIVOS_CAMBIO_TITULARIDAD
FOR EACH ROW
BEGIN
	SELECT GEN_ID_MOTIVO_CT.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/


-- *********************************************************************************************
-- Autor: 31/01/2005 Lucas Fernández Pérez. 
-- Acción: Genera el siguiente ID para la tabla HISTO_DOMICILIACIONES
-- *********************************************************************************************
CREATE OR REPLACE TRIGGER T_HISTO_DOMICILIACIONES
BEFORE INSERT ON HISTO_DOMICILIACIONES
FOR EACH ROW
BEGIN
  SELECT GEN_ID_HISTO_DOMICILIACIONES.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

-- *********************************************************************************************
-- Autor: 12/04/2005 Mª del Carmen Junco Gómez. 
-- Acción: Genera el siguiente ID para la tabla LOG_DOCUMENTOS
-- *********************************************************************************************

CREATE OR REPLACE TRIGGER T_INS_LOG_DOCU
BEFORE INSERT ON LOG_DOCUMENTOS
FOR EACH ROW
BEGIN

	SELECT GEN_LOGDOCU.NEXTVAL INTO :NEW.ID FROM DUAL;

END;
/

/********************************************************************/
COMMIT;
/********************************************************************/
