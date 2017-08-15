/*******************************************************************************
TRIGGERS PARA AGUAS

MODIFICACIÓN: 30/08/2001 Antonio Pérez Caballero.
MODIFICACION: 02/02/2004. Gloria Maria Calle Hernandez. 
			  Eliminada llamada a ADD_TRIBUTOS_CONTRI, pues la tabla TributosContri sobre la cual
			  insertaba pasa a rellenarse como una tabla temporal y dicho procedimiento ha sido eliminado
MODIFICACION: 04/02/2004. Gloria Maria Calle Hernandez. 
			  Eliminada llamada a ADD_DOMI_CONTRI, pues la tabla DomiContri sobre la cual
			  insertaba pasa a rellenarse como una tabla temporal y dicho procedimiento ha sido eliminado
*******************************************************************************************/
CREATE OR REPLACE TRIGGER AGUAS_ADD_TR
BEFORE INSERT ON AGUA
FOR EACH ROW
DECLARE 
  xNUEVO_AB		INTEGER;
BEGIN
  
  IF (:NEW.ID=0) THEN

	SELECT GENAGUAS.NEXTVAL INTO xNUEVO_AB FROM DUAL;

	UPDATE USUARIOSGT SET ID_AGUA=xNUEVO_AB
			WHERE USUARIO=USER;

	:NEW.ID:=xNUEVO_AB;

  ELSE

	UPDATE USUARIOSGT SET ID_AGUA=:NEW.ID
			WHERE USUARIO=USER;
  END IF;


  -- Si existe el Facturar a, pasamos al titular del recibo
  -- como responsable solidario
  IF :NEW.DNI_FACTURA IS NOT NULL THEN
  
    INSERT INTO COTITULARES (PROGRAMA,NIF,ID_CONCEPTO) 
	VALUES ('AGUA',:NEW.NIF,:NEW.ID);
   
	:NEW.COTITULARES:='S';
	
  END IF;

END;
/


/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_RECIBOS_AGUA
BEFORE INSERT ON RECIBOS_AGUA
FOR EACH ROW
BEGIN
   SELECT GENRECIAGUA.NEXTVAL INTO :NEW.ID FROM DUAL;
END T_INS_RECIBOS_AGUA;
/


/********************************************************************************************/
CREATE OR REPLACE TRIGGER T_INS_DESGLOSE_AGUAS
BEFORE INSERT ON DESGLOSE_AGUAS
FOR EACH ROW
BEGIN
   SELECT GENDESAG.NEXTVAL INTO :NEW.ID FROM DUAL;
END T_INS_DESGLOSE_AGUAS;
/


/********************************************************************************************/
CREATE OR REPLACE TRIGGER T_INS_VAR_RECIBOS_AGUA
BEFORE INSERT ON VARIACIONES_RECIBOS_AGUA
FOR EACH ROW
BEGIN
   SELECT GENVARAG.NEXTVAL INTO :NEW.ID FROM DUAL;
   update usuariosGT set id_agua=:New.Id where usuario=user;
END T_INS_VAR_RECIBOS_AGUA;
/


/********************************************************************************************/
CREATE OR REPLACE TRIGGER T_INS_SERVICIOS
BEFORE INSERT ON SERVICIOS
FOR EACH ROW
BEGIN
    SELECT GENSERV.NEXTVAL INTO :NEW.ID FROM DUAL;
END T_INS_SERVICIOS;
/


/********************************************************************************************/
-- Modificado: 31/01/2005. Lucas Fernandez Pérez. Se añade un historico de 
--	modificaciones de domiciliaciones, HISTO_DOMICILIACIONES, que suplanta
--  a los campos USR_CHG CUENTA y F_CHG_ CUENTA de la tabla de AGUA.
-- Modificación: 12/06/2006 Lucas Fernández Pérez. El historico de cambios de titularidad 
-- no controlaba los valores null para DNI_FACTURA ni para REPRESENTANTE (NIF y DNI_TITULAR
-- no porque no pueden ser null) y cuando pasaban de null a tener valor o al revés, 
-- no se grababa informacion alguna en el histórico
--
CREATE OR REPLACE TRIGGER T_UPD_AGUA
BEFORE UPDATE ON AGUA
FOR EACH ROW
DECLARE
	xTEXTO VARCHAR2(512);
    xMOTIVO  VARCHAR2(512);
BEGIN
	/*PARA CAMBIAR DE LECTURA ACTUAL A ANTERIOR*/
	IF (:NEW.ACTUAL=0 AND :OLD.ACTUAL<>0) THEN
	   :NEW.ANTERIOR := :OLD.ACTUAL;
	   :NEW.F_L_ANTERIOR := :OLD.F_L_ACTUAL;
	   :NEW.LECTURA1   := :OLD.ANTERIOR;
	   :NEW.LECTURA2   := :OLD.LECTURA1;
	   :NEW.LECTURA3   := :OLD.LECTURA2;
	   :NEW.LECTURA4   := :OLD.LECTURA3;
	   :NEW.F_L_ACTUAL := NULL;
	END IF;

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
          (:OLD.ID, 'AGUA',xMOTIVO, :OLD.DOMICILIADO, :OLD.F_DOMICILIACION,
           :OLD.DNI_TITULAR, :OLD.ENTIDAD, :OLD.SUCURSAL, :OLD.DC, :OLD.CUENTA);
	END IF;
		
	-- cambio de titular del tributo
	IF (:NEW.NIF<>:OLD.NIF) THEN
		SELECT TEXTO INTO xTEXTO FROM USUARIOSGT WHERE USUARIO=USER;
		INSERT INTO MOTIVOS_CAMBIO_TITULARIDAD
			(IDCAMBIO,PROGRAMA,NIF,TIPO_TITULAR,MOTIVO)
		VALUES
			(:NEW.ID,'AGUA',:OLD.NIF,'T',xTEXTO);
	END IF;
	-- cambio de la persona a la que se le factura
	IF (:NEW.DNI_FACTURA<>:OLD.DNI_FACTURA) 
		OR (:NEW.DNI_FACTURA IS NULL AND :OLD.DNI_FACTURA IS NOT NULL)
		OR (:NEW.DNI_FACTURA IS NOT NULL AND :OLD.DNI_FACTURA IS NULL)
		THEN
		SELECT TEXTO INTO xTEXTO FROM USUARIOSGT WHERE USUARIO=USER;
		INSERT INTO MOTIVOS_CAMBIO_TITULARIDAD
			(IDCAMBIO,PROGRAMA,NIF,TIPO_TITULAR,MOTIVO)
		VALUES
			(:NEW.ID,'AGUA',:OLD.DNI_FACTURA,'F',xTEXTO);
	END IF;
	-- cambio del representante
	IF (:NEW.DNI_REPRESENTANTE<>:OLD.DNI_REPRESENTANTE)
		OR (:NEW.DNI_REPRESENTANTE IS NULL AND :OLD.DNI_REPRESENTANTE IS NOT NULL)
		OR (:NEW.DNI_REPRESENTANTE IS NOT NULL AND :OLD.DNI_REPRESENTANTE IS NULL)
		THEN
		SELECT TEXTO INTO xTEXTO FROM USUARIOSGT WHERE USUARIO=USER;
		INSERT INTO MOTIVOS_CAMBIO_TITULARIDAD
			(IDCAMBIO,PROGRAMA,NIF,TIPO_TITULAR,MOTIVO)
		VALUES
			(:NEW.ID,'AGUA',:OLD.DNI_REPRESENTANTE,'R',xTEXTO);
	END IF;
END;
/

/*******************************************************************************
Autor: Antonio Pérez Caballero
Fecha: 30/08/2001
Acción: Modificar un agua y controlar la figura del responsable solidario
        pues si tenemos un campo llamado facturar a relleno este pasa a ser el
        sujeto pasivo del tributo y el NIF será responsable solidario, en caso 
        contrario el sujeto pasivo será el del campo NIF.
Modificación: 15/10/2006 Lucas Fernández Pérez. Grababa en Cotitulares el programa 'EXACCIONES'
		en lugar de 'AGUA'
*******************************************************************************/
CREATE OR REPLACE TRIGGER AGUA_MODCoti
BEFORE UPDATE ON AGUA
FOR EACH ROW
DECLARE 
  xCUANTOS INTEGER;
BEGIN

  -- Se modifica y se añade el campo facturar a
  -- pasamos al titular del tributo como responsable solidario
  IF :NEW.DNI_FACTURA IS NOT NULL AND :OLD.DNI_FACTURA IS NULL THEN
    INSERT INTO COTITULARES (PROGRAMA,NIF,ID_CONCEPTO) 
	VALUES ('AGUA',:NEW.NIF,:NEW.ID);
   :NEW.COTITULARES:='S';
  END IF;

  -- Se modifica y se quita el facturar a
  -- quitamos al tirular del tributo como responsable solidario
  -- pasa a ser sujeto pasivo
  IF :NEW.DNI_FACTURA IS NULL AND :OLD.DNI_FACTURA IS NOT NULL THEN
    DELETE FROM COTITULARES WHERE ID_CONCEPTO=:NEW.ID AND NIF=:NEW.NIF;
    SELECT COUNT(*) INTO xCUANTOS FROM COTITULARES WHERE ID_CONCEPTO=:NEW.ID;
    IF xCUANTOS = 0 THEN
      :NEW.COTITULARES:='N';
    END IF;
  END IF;

END AGUA_MODCoti;
/

/********************************************************************/
COMMIT;
/********************************************************************/
