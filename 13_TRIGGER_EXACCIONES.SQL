/* TRIGGER DE EXACCIONES */

/* ************************* */
/* Añadir una nueva exaccion */

-- modificación 21/08/2001 Antonio Pérez Caballero
-- modificación 18/09/2002 M. Carmen Junco Gómez. Se quita la tabla Tarifas_Exacciones.
-- modificación 12/06/2003 M. Carmen Junco Gómez. En la descripción de domicontri se estaba
-- escribiendo TARIFA: COD_TARIFA, en vez de la descripción de la tarifa.
/*******************************************************************************
MODIFICACION: 02/02/2004. Gloria Maria Calle Hernandez. 
			  Eliminada llamada a ADD_TRIBUTOS_CONTRI, pues la tabla TributosContri sobre la cual
			  insertaba pasa a rellenarse como una tabla temporal y dicho procedimiento ha sido eliminado
MODIFICACION: 04/02/2004. Gloria Maria Calle Hernandez. 
			  Eliminada llamada a ADD_DOMI_CONTRI, pues la tabla DomiContri sobre la cual
			  insertaba pasa a rellenarse como una tabla temporal y dicho procedimiento ha sido eliminado
*******************************************************************************************/
CREATE OR REPLACE TRIGGER EXACCIONES_ADD_TR
BEFORE INSERT ON EXACCIONES 
FOR EACH ROW
DECLARE
  xNUEVO_AB	INTEGER;
BEGIN
  
  IF (:NEW.ABONADO=0) THEN

	SELECT GENEXACC.NEXTVAL INTO xNUEVO_AB FROM DUAL;

	UPDATE USUARIOSGT SET LAST_EXACCION=xNUEVO_AB 
		WHERE USUARIO=USER;

	:NEW.ABONADO:=xNUEVO_AB;

  ELSE

	UPDATE USUARIOSGT SET LAST_EXACCION=:NEW.ABONADO
 	 WHERE USUARIO=USER;

  END IF;

  -- Si existe el Facturar a, pasamos al titular del recibo
  -- como responsable solidario
  IF :NEW.DNI_FACTURA IS NOT NULL THEN
    
    INSERT INTO COTITULARES (PROGRAMA,NIF,ID_CONCEPTO) 
	VALUES ('EXACCIONES',:NEW.NIF,:NEW.ABONADO);
    
	:NEW.COTITULARES:='S';
  
  END IF;

END;
/


-- Autor: Antonio Pérez Caballero
-- Fecha: 22 Agosto 2.001
-- Modificar una exaccion y controlar la figura del responsable solidario
-- pues si tenemos un campo llamado facturar a relleno este pasa a ser el
-- sujeto pasivo del tributo y el NIF será responsable solidario, en caso 
-- contrario el sujeto pasivo será el del campo NIF.
-- Fecha: 23/09/2002 Mª Carmen Junco Gómez. Indicar que usuario y en que fecha
-- se modifican los datos de una domiciliación. 
-- Modificado: 31/01/2005. Lucas Fernandez Pérez. Se añade un historico de 
--	modificaciones de domiciliaciones, HISTO_DOMICILIACIONES, que suplanta
-- a los campos USR_CHG CUENTA y F_CHG_ CUENTA de la tabla de EXACCIONES.
-- Modificación: 01/02/2005 M. Carmen Junco Gómez. Si hay una modificación en la
-- titularidad (titular, facturar a o representante) se guardará un histórico 
-- con la información que se reemplaza.
-- Modificación: 12/06/2006 Lucas Fernández Pérez. El cambio anterior no controlaba
-- los valores null para DNI_FACTURA ni para REPRESENTANTE (NIF y DNI_TITULAR
-- no porque no pueden ser null) y cuando pasaban de null a tener valor o al revés, 
-- no se grababa informacion alguna en el histórico

CREATE OR REPLACE TRIGGER EXACCIONES_MODIFICA
BEFORE UPDATE ON EXACCIONES 
FOR EACH ROW
DECLARE 
  xCUANTOS INTEGER;
  xMOTIVO  VARCHAR2(512);
  xTEXTO	  VARCHAR2(512);
BEGIN

	-- Se modifica y se añade el campo facturar a
	-- pasamos al titular del tributo como responsable solidario
	IF :NEW.DNI_FACTURA IS NOT NULL AND :OLD.DNI_FACTURA IS NULL THEN
 		INSERT INTO COTITULARES (PROGRAMA,NIF,ID_CONCEPTO) 
		VALUES ('EXACCIONES',:NEW.NIF,:NEW.ABONADO);
   		:NEW.COTITULARES:='S';
	END IF;

	-- Se modifica y se quita el facturar a
	-- quitamos al tirular del tributo como responsable solidario
	-- pasa a ser sujeto pasivo
	IF :NEW.DNI_FACTURA IS NULL AND :OLD.DNI_FACTURA IS NOT NULL THEN
  		DELETE FROM COTITULARES WHERE ID_CONCEPTO=:NEW.ABONADO AND NIF=:NEW.NIF;
  		SELECT COUNT(*) INTO xCUANTOS FROM COTITULARES WHERE ID_CONCEPTO=:NEW.ABONADO;
  		IF xCUANTOS = 0 THEN
     		:NEW.COTITULARES:='N';
  		END IF;
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
       (:OLD.ABONADO, 'EXACCIONES',xMOTIVO, :OLD.DOMICILIADO, :OLD.F_DOMICILIACION,
        :OLD.DNI_TITULAR, :OLD.ENTIDAD, :OLD.SUCURSAL, :OLD.DC, :OLD.CUENTA);
	END IF;
	
	-- cambio de titular del tributo
	IF (:NEW.NIF<>:OLD.NIF) THEN
		SELECT TEXTO INTO xTEXTO FROM USUARIOSGT WHERE USUARIO=USER;
		INSERT INTO MOTIVOS_CAMBIO_TITULARIDAD
			(IDCAMBIO,PROGRAMA,NIF,TIPO_TITULAR,MOTIVO)
		VALUES
			(:NEW.ABONADO,'EXACCIONES',:OLD.NIF,'T',xTEXTO);
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
			(:NEW.ABONADO,'EXACCIONES',:OLD.DNI_FACTURA,'F',xTEXTO);
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
			(:NEW.ABONADO,'EXACCIONES',:OLD.REPRESENTANTE,'R',xTEXTO);
	END IF;

END;
/

/*****************************************************************************************/
CREATE OR REPLACE TRIGGER ADD_RECI_EXAC  
BEFORE INSERT ON RECIBOS_EXAC
FOR EACH ROW
BEGIN
   SELECT GENRECIBOS_EXACC.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/

/********************************************************************/
COMMIT;
/********************************************************************/
