/*******************************************************************************************
MODIFICACION: 02/02/2004. Gloria Maria Calle Hernandez. 
			  Eliminada llamada a ADD_TRIBUTOS_CONTRI, pues la tabla TributosContri sobre la cual
			  insertaba pasa a rellenarse como una tabla temporal y dicho procedimiento ha sido eliminado
MODIFICACION: 04/02/2004. Gloria Maria Calle Hernandez. 
			  Eliminada llamada a ADD_DOMI_CONTRI, pues la tabla DomiContri sobre la cual
			  insertaba pasa a rellenarse como una tabla temporal y dicho procedimiento ha sido eliminado
*******************************************************************************************/
CREATE OR REPLACE TRIGGER T_INS_VEHICULOS
BEFORE INSERT ON VEHICULOS
FOR EACH ROW
BEGIN

	SELECT GENVEHI.NEXTVAL INTO :NEW.ABONADO FROM DUAL;

	UPDATE USUARIOSGT SET LAST_VEHI=:NEW.ABONADO WHERE USUARIO=USER; 

	--Añadimos el vehículo a los iden de recaudación 
    ADDMOD_VEHI_RECATRIBU('A',:NEW.ABONADO,:NEW.NIF,GETMATRICULA(:NEW.MATRICULA,:NEW.NUMERO,:NEW.LETRA),:NEW.MARCA,:NEW.MODELO);

END;
/


/************************************************************************************************
MODIFICACION: 02/02/2004. Gloria Maria Calle Hernandez. 
			  Eliminada llamada a ADD_TRIBUTOS_CONTRI y MOD_TRIBUTOS_CONTRI, pues la tabla 
			  TributosContri sobre la cual insertaba o actualizaba respectivamente, pasa a 
			  rellenarse como una tabla temporal y dicho procedimiento ha sido eliminado
MODIFICACION: 04/02/2004. Gloria Maria Calle Hernandez. 
			  Eliminada llamada a ADD_DOMI_CONTRI,MOD_DOI_CONTRI,BORRADOMI, pues la tabla DomiContri 
			  sobre la cual actuaban pasa a rellenarse como una tabla temporal y dichos procedimiento 
			  han sido eliminados
MODIFICACIÓN: 31/01/2005 M. Carmen Junco Gómez.
			  Si hay cambios en el NIF o en el REPRESENTANTE, se almacenará en un histórico junto con 
			  un motivo del cambio.
MODIFICACIÓN: 01/02/2005. Lucas Fernandez Pérez. 
			  Se añade un historico de modificaciones de domiciliaciones, HISTO_DOMICILIACIONES, 
			  que suplanta a los campos USR_CHG CUENTA y F_CHG_ CUENTA de la tabla de VEHICULOS
MODIFICACIÓN: 12/06/2006 Lucas Fernández Pérez. 
			  El historico de cambios de titularidad no controlaba el valor null para REPRESENTANTE 
			  (NIF y TITULAR no porque no pueden ser null) y cuando pasaba de null a tener valor 
			  o al revés, no se grababa informacion alguna en el histórico
***************************************************************************************************/
CREATE OR REPLACE TRIGGER T_UPDBEFORE_VEHI
BEFORE UPDATE ON VEHICULOS
FOR EACH ROW
DECLARE
  xTEXTO VARCHAR2(512);
  xMOTIVO  VARCHAR2(512);
BEGIN

	-- si ha habido algún cambio en los datos de domiciliación, indicar el usuario que 
	-- lo realiza y la fecha
	IF ((:NEW.DOMICILIADO<>:OLD.DOMICILIADO) OR (trunc(:NEW.F_DOMICILIACION,'dd')<>trunc(:OLD.F_DOMICILIACION,'dd')) OR 
   	       (:NEW.ENTIDAD<>:OLD.ENTIDAD) OR (:NEW.SUCURSAL<>:OLD.SUCURSAL) OR 
           (:NEW.DC<>:OLD.DC) OR (:NEW.CUENTA<>:OLD.CUENTA) OR 
           (:NEW.TITULAR<>:OLD.TITULAR)) THEN
		
        SELECT TEXTO2 INTO xMOTIVO FROM USUARIOSGT WHERE USUARIO=USER;
		
        INSERT INTO HISTO_DOMICILIACIONES
          (IDPROGRAMA, PROGRAMA, MOTIVO, DOMICILIADO, F_DOMICILIACION,
           NIF_TITULAR, ENTIDAD, SUCURSAL, DC, CUENTA)
        VALUES
          (:OLD.ABONADO, 'VEHICULOS',xMOTIVO, :OLD.DOMICILIADO, :OLD.F_DOMICILIACION,
           :OLD.TITULAR, :OLD.ENTIDAD, :OLD.SUCURSAL, :OLD.DC, :OLD.CUENTA);
	END IF;
  
  	-- cambio de titular del tributo
	IF (:NEW.NIF<>:OLD.NIF) THEN
		SELECT TEXTO INTO xTEXTO FROM USUARIOSGT WHERE USUARIO=USER;
		INSERT INTO MOTIVOS_CAMBIO_TITULARIDAD
			(IDCAMBIO,PROGRAMA,NIF,TIPO_TITULAR,MOTIVO)
		VALUES
			(:NEW.ABONADO,'VEHICULOS',:OLD.NIF,'T',xTEXTO);
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
			(:NEW.ABONADO,'VEHICULOS',:OLD.REPRESENTANTE,'R',xTEXTO);
	END IF;

END;
/


/*******************************************************************************************
MODIFICACION: 02/02/2004. Gloria Maria Calle Hernandez. 
			  Eliminada llamada a MOD_TRIBUTOS_CONTRI, pues la tabla TributosContri sobre la cual
			  actuaba pasa a rellenarse como una tabla temporal y dicho procedimiento ha sido eliminado
MODIFICACION: 04/02/2004. Gloria Maria Calle Hernandez. 
			  Eliminada llamada a MOD_DOMI_CONTRI, pues la tabla DomiContri sobre la cual
			  actuaba pasa a rellenarse como una tabla temporal y dicho procedimiento ha sido eliminado
*******************************************************************************************/
CREATE OR REPLACE TRIGGER T_UPD_VEHI
AFTER UPDATE OF NIF,MATRICULA,NUMERO,LETRA,MARCA,MODELO ON VEHICULOS
FOR EACH ROW
BEGIN

  -- Modificamos los datos del vehiculo
  ADDMOD_VEHI_RECATRIBU('M',:OLD.ABONADO,:NEW.NIF,GETMATRICULA(:NEW.MATRICULA,:NEW.NUMERO,:NEW.LETRA),:NEW.MARCA,:NEW.MODELO);

END;
/


/********************************************************************/
CREATE OR REPLACE TRIGGER TVEHIALTABAJA
AFTER UPDATE OF F_BAJA ON VEHICULOS
FOR EACH ROW
BEGIN

   -- Lo borramos de la tabla de vehículos de recaudación
   delete from VEHICULOSR where ABONADO_VEHI=:NEW.ABONADO;

   IF (:NEW.F_BAJA IS NULL) AND (:OLD.F_BAJA IS NOT NULL) THEN

	 -- Si restauramos un vehiciulo lo añadimos a la tabla de vehículos de recaudación
     ADDMOD_VEHI_RECATRIBU('A',:OLD.ABONADO,:NEW.NIF,GETMATRICULA(:NEW.MATRICULA,:NEW.NUMERO,:NEW.LETRA),:NEW.MARCA,:NEW.MODELO);

   END IF;   

END;
/


/********************************************************************************************/
CREATE OR REPLACE TRIGGER T_INS_BONIFI_VEHICULOS
BEFORE INSERT ON BONIFI_VEHICULOS
FOR EACH ROW
BEGIN

  SELECT GENBONI.NEXTVAL INTO :NEW.ID FROM DUAL;
  UPDATE USUARIOSGT SET LAST_INT=:NEW.ID 
  WHERE USUARIO=USER; 

END;
/


/********************************************************************************************/
CREATE OR REPLACE TRIGGER T_INS_TARIFAS_VEHICULOS
BEFORE INSERT ON TARIFAS_VEHICULOS
FOR EACH ROW
BEGIN
   SELECT GENTARIFAS_VEHI.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/


/********************************************************************************************/
CREATE OR REPLACE TRIGGER T_INS_RECIBOS_VEHI
BEFORE INSERT ON RECIBOS_VEHI
FOR EACH ROW
BEGIN
   SELECT GENRECIBOS_VEHI.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/


/********************************************************************************************/
CREATE OR REPLACE TRIGGER T_INS_TRAFICO_NEW
BEFORE INSERT ON TRAFICO_NEW
FOR EACH ROW
BEGIN
   SELECT GENTRAFICO_NEW.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/


/********************************************************************/
COMMIT;
/********************************************************************/
