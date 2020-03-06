--1. Create sequence to generate transaction ID 
 CREATE SEQUENCE transaction_id
 MINVALUE 1
 MAXVALUE 99
 START WITH 1
 INCREMENT BY   1
 NOCACHE
 NOCYCLE;
 
 --2. Conference Automation
 CREATE OR REPLACE PACKAGE CONFERENCE_AUTOMATION
 IS
 PROCEDURE INSERT_BOOKING(p_ccode COMPANY.CCODE%TYPE, p_hname HALLS.HNAME%TYPE , p_startdate BOOKINGS.STARTDATE%TYPE , p_enddate BOOKINGS.ENDDATE%TYPE);
 PROCEDURE NO_OF_BOOKINGS(p_htype HALLS.HTYPE%TYPE);
 PROCEDURE BOOKING_REPORT(p_ccode COMPANY.CCODE%TYPE);
 PROCEDURE RENT_CALCULATION(p_hname HALLS.HNAME%TYPE, p_startdate BOOKINGS.STARTDATE%TYPE , p_enddate BOOKINGS.ENDDATE%TYPE);
 END CONFERENCE_AUTOMATION;
 /
 
  CREATE OR REPLACE PACKAGE BODY CONFERENCE_AUTOMATION AS
-- 2aa 
 PROCEDURE INSERT_BOOKING(p_ccode COMPANY.CCODE%TYPE, p_hname HALLS.HNAME%TYPE , p_startdate BOOKINGS.STARTDATE%TYPE , p_enddate BOOKINGS.ENDDATE%TYPE)
 IS
 v_ccode_check number(2);
 v_hname_check number(2);
 INVALID_INSERT EXCEPTION;
 BEGIN
 SELECT COUNT(*) INTO v_ccode_check FROM COMPANY WHERE CCODE = p_ccode;
 SELECT COUNT(*) INTO v_hname_check FROM HALLS WHERE HNAME = p_hname;
 IF (v_ccode_check < 1 or v_hname_check < 1)THEN
 RAISE  INVALID_INSERT;
 ELSE
 INSERT INTO BOOKING values (transaction_id.NEXTVAL, p_ccode , p_hname , p_startdate , p_enddate);
 COMMIT;
 DBMS_OUTPUT.PUT_LINE(p_ccode || ' has booked ' || p_hname || ' from ' || p_startdate || ' to ' || p_enddate );
 END IF;

 EXCEPTION 
  WHEN  INVALID_INSERT THEN
  DBMS_OUTPUT.PUT_LINE('The hall name or company code is not valid. Please check');   
 END INSERT_BOOKING;
 -- 2b
 PROCEDURE NO_OF_BOOKINGS(p_htype HALLS.HTYPE%TYPE)
 IS
 v_htype_check number(2);
 v_booking_count number(2);
 INVALID_HTYPE EXCEPTION;
 BEGIN
 SELECT COUNT(*) INTO v_htype_check FROM HALLS WHERE HTYPE = p_htype;
 IF v_htype_check = 0 THEN
 RAISE  INVALID_HTYPE;
 
 ELSE
 SELECT SUM(NOOFBOOKINGS) INTO v_booking_count FROM HALLS WHERE HTYPE = p_htype;
 DBMS_OUTPUT.PUT_LINE('The number of bookings for htype ' || p_htype || ' is ' || v_booking_count);
 END IF;
 EXCEPTION
 WHEN INVALID_HTYPE THEN
 DBMS_OUTPUT.PUT_LINE('Please enter valid hotel type');
 END NO_OF_BOOKINGS;
 
 --2c
 PROCEDURE BOOKING_REPORT(p_ccode COMPANY.CCODE%TYPE)
 IS
 v_ccode_check number(2);
 v_booking_count number(2);
  CURSOR c_booking_details is
 SELECT B.TRANSID , B.HNAME , B.STARTDATE , B.ENDDATE FROM BOOKING B WHERE B.CCODE = p_ccode;
 bd c_booking_details%rowtype;
 INVALID_CCODE EXCEPTION;
 
 BEGIN
 SELECT COUNT(*) INTO v_ccode_check FROM COMPANY WHERE CCODE = p_ccode;
 IF v_ccode_check = 0 THEN
 RAISE INVALID_CCODE;
 ELSE
 DBMS_OUTPUT.PUT_LINE('The booking details of ' || p_ccode || ' is/are below');
 OPEN c_booking_details;
 LOOP
 FETCH c_booking_details into bd;
 EXIT WHEN c_booking_details%NOTFOUND;
 DBMS_OUTPUT.PUT_LINE(bd.TRANSID || ' ' || bd.HNAME ||' ' || bd.STARTDATE ||' ' || bd.ENDDATE);
 END LOOP;
 END IF;
 EXCEPTION
 WHEN INVALID_CCODE THEN
 DBMS_OUTPUT.PUT_LINE('Please enter valid company code');
 END BOOKING_REPORT;
 
 --2d
 PROCEDURE RENT_CALCULATION(p_hname HALLS.HNAME%TYPE, p_startdate BOOKINGS.STARTDATE%TYPE , p_enddate BOOKINGS.ENDDATE%TYPE) IS
 v_rent HALLS.RENT%TYPE;
 v_no_of_days number(3):=(to_date(to_char(p_enddate,'DD-MM-YYYY')) - to_date(to_char(p_startdate,'DD-MM-YYYY')));
 v_total HALLS.RENT%TYPE;
 BEGIN
 SELECT RENT INTO v_rent FROM HALLS WHERE HNAME = p_hname; 
 v_total := v_rent * v_no_of_days;
 DBMS_OUTPUT.PUT_LINE('The rent to ' || p_hname || ' for ' || v_no_of_days || ' days is Rs. ' || v_total);
 EXCEPTION WHEN NO_DATA_FOUND THEN
 DBMS_OUTPUT.PUT_LINE('Please enter valid hall name');
 END RENT_CALCULATION;

--2e
Function validate_company_code return Boolean is
cursor c_ccode is
select ccode from company;
v_ccode COMPANY.CCODE%TYPE;
BEGIN

open c_ccode;
fetch c_ccode into v_ccode;
close c_ccode;

IF (v_ccode < 100 or v_ccode > 999 )THEN
RETURN FALSE;
ELSE
RETURN TRUE;
END IF;
END validate_company_code;

Function validate_hall_type return Boolean is
cursor c_htype is
select htype from halls;
v_htype HALLS.HTYPE%TYPE;
BEGIN

open c_htype;
fetch c_htype into v_htype;
close c_htype;

IF (v_htype != 'Small' or v_htype != 'Medium' or v_htype != 'Large' )THEN
RETURN FALSE;
ELSE
RETURN TRUE;
END IF;
END validate_hall_type;

END CONFERENCE_AUTOMATION;
 /
 
--3. Trigger
CREATE OR REPLACE TRIGGER trUpdate 
AFTER INSERT ON BOOKING FOR EACH ROW
DECLARE
v_no_booked HALLS.NOOFBOOKINGS%TYPE;

BEGIN
SELECT NOOFBOOKINGS INTO v_no_booked FROM HALLS WHERE HNAME = :new.HNAME;
UPDATE HALLS SET NOOFBOOKINGS = (v_no_booked + 1) WHERE HNAME = :new.HNAME;
DBMS_OUTPUT.PUT_LINE('The bookings have been updated');
END;
/
