CREATE OR REPLACE TRIGGER T_INS_INSPECCION
BEFORE INSERT ON INSPECCIONES
FOR EACH ROW
BEGIN
   SELECT GENINSPE.NEXTVAL INTO :NEW.ID FROM DUAL;
END T_INS_INSPECCION;
/

/*************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_SEGUIINSPE
BEFORE INSERT ON SEGUIMIENTO_INSPE
FOR EACH ROW
BEGIN
   SELECT GENSEGUIINSPE.NEXTVAL INTO :NEW.ID FROM DUAL;
END T_INS_SEGUIINSPE;
/

/*************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_DOCSEGUI
BEFORE INSERT ON DOCSEGUI
FOR EACH ROW
BEGIN
   SELECT GENDOCINSPE.NEXTVAL INTO :NEW.ID FROM DUAL;
END T_INS_DOCSEGUI;
/

/*************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_NOTIINSPE
BEFORE INSERT ON NOTIFICACIONES_INSPE
FOR EACH ROW
BEGIN
   SELECT GENNOTIINSPE.NEXTVAL INTO :NEW.ID FROM DUAL;
END T_INS_NOTIINSPE;
/

/*************************************************************************/

-- si modificamos un apunte e indicamos que el documento ha de ser notificado,
-- insertamos una nueva tupla en la tabla de notificaciones; Si por el contrario
-- se quita la señal de notificación, borramos la tupla/s de la tabla de notificaciones
-- para ese apunte en el seguimiento de un expediente de inspección.

CREATE OR REPLACE TRIGGER T_MODIFY_SEGUI
AFTER UPDATE ON SEGUIMIENTO_INSPE
FOR EACH ROW
BEGIN

   IF (:NEW.NOTIFICABLE<>:OLD.NOTIFICABLE) THEN
      IF (:NEW.NOTIFICABLE='S') THEN
         INSERT INTO NOTIFICACIONES_INSPE(IDSEGUI,N_ENVIOS,F_1INTENTO,F_INTENTO)
	   VALUES (:NEW.ID,1,SYSDATE,SYSDATE); 
      ELSIF (:NEW.NOTIFICABLE='N') THEN
         DELETE FROM NOTIFICACIONES_INSPE WHERE IDSEGUI=:NEW.ID;
	END IF;
   END IF;

END T_MODIFY_SEGUI;
/

/*************************************************************************/
COMMIT;
/*************************************************************************/


