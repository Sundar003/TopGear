CREATE OR REPLACE PACKAGE BANK_ACC_INTEREST_CALC IS
/*Record to store temparary records*/

TYPE t_rec_txn IS RECORD
  ( 
   v_txn_acct_no ACCOUNT_TXN.TXN_ACCT_NO%TYPE,
   v_txn_date ACCOUNT_TXN.TXN_TIMESTAMP%TYPE,
    v_txn_type ACCOUNT_TXN.TXN_TYPE%TYPE,
    v_txn_amount ACCOUNT_TXN.TXN_AMOUNT%TYPE,
   v_txn_acct_bal ACCOUNT_TXN.TXN_ACCT_BAL%TYPE,
   v_balance number(15,7),
   v_no_of_days number(3),
  v_interest_amt NUMBER(15,7)
   );
   
/*Collection to store temparary records*/
TYPE t_transaction IS TABLE OF t_rec_txn INDEX BY PLS_INTEGER;

FUNCTION NO_OF_DAYS(p_date IN TIMESTAMP) RETURN NUMBER; /*Function to figure year wheather it is leap or nornal*/
FUNCTION INTEREST_RATE_PER_DAY(p_date IN TIMESTAMP) RETURN NUMBER; /*Calculate interest rate on daily basis*/
PROCEDURE SET_QUARTER(p_cur_date IN TIMESTAMP,p_first_date OUT TIMESTAMP,p_last_date OUT TIMESTAMP); /* To find which quarter is it*/
FUNCTION DUPLICATE_RUN_CHECK(p_date IN DATE) RETURN BOOLEAN; /*to check already execution*/
PROCEDURE TRANSACTION_CALCULATION(p_acct_no NUMBER,p_cust_id IN NUMBER,p_cust_transaction OUT t_transaction); /*to get all quarter transaction and daily interest of a customer*/
PROCEDURE credit_interest; /*Credit interest to customer account*/

END BANK_ACC_INTEREST_CALC;
/

CREATE OR REPLACE PACKAGE BODY BANK_ACC_INTEREST_CALC IS

/* Fucntion to get number of days in a year*/
FUNCTION NO_OF_DAYS(p_date IN TIMESTAMP) RETURN NUMBER
IS
v_year NUMBER(4);
v_no_of_days NUMBER(3);
BEGIN
v_year := TO_NUMBER(TO_CHAR(p_date,'YYYY'));
IF MOD(v_year,400) = 0 OR (MOD(v_year,4) = 0 AND MOD(v_year,100)<>0) THEN
v_no_of_days := 366;
ELSE
v_no_of_days := 365;
END IF;
RETURN v_no_of_days;
END NO_OF_DAYS;

/*Function to get  interest per day.*/
FUNCTION INTEREST_RATE_PER_DAY(p_date IN TIMESTAMP) RETURN NUMBER
IS
v_annual_rate NUMBER(4,2);
v_daily_interest_rate NUMBER(15,7);
BEGIN
SELECT RATE INTO v_annual_rate FROM INTEREST_RATE
WHERE ACCT_TYPE = 1
AND EFFECTIVE_FROM <= p_date
AND EFFECTIVE_TILL >= p_date;
v_daily_interest_rate := v_annual_rate/NO_OF_DAYS(p_date);
RETURN v_daily_interest_rate;
EXCEPTION
WHEN NO_DATA_FOUND THEN
RETURN 0;
END INTEREST_RATE_PER_DAY;

/*Procedure to find which quarter it is and get start and end date of quarter.*/
PROCEDURE SET_QUARTER(p_cur_date IN TIMESTAMP,p_first_date OUT TIMESTAMP,p_last_date OUT TIMESTAMP)
IS
v_month VARCHAR2(3);
v_year VARCHAR2(4);
BEGIN
v_month:=to_char(p_cur_date,'MON');
v_year:=to_char(p_cur_date,'YYYY');
CASE
WHEN v_month IN('JAN','FEB','MAR') THEN
p_first_date:='01-JAN-'||v_year||' 12:00:00.000000 AM';
p_last_date:='31-MAR-'||v_year||' 11:59:59.000000 PM';
WHEN v_month IN('APR','MAY','JUN') THEN
p_first_date:='01-APR-'||v_year||' 12:00:00.000000 AM';
p_last_date:='30-JUN-'||v_year||' 11:59:59.000000 PM';
WHEN v_month IN('JUL','AUG','SEP') THEN
p_first_date:='01-JUL-'||v_year|| '12:00:00.000000 AM';
p_last_date:='30-SEP-'||v_year||' 11:59:59.000000 PM';
ELSE
p_first_date:='01-OCT-'||v_year||' 12:00:00.000000 AM';
p_last_date:='31-DEC-'||v_year||' 11:59:59.000000 PM';
END CASE;
END SET_QUARTER;

/*Function to check wheather the interest script is already executed.*/
FUNCTION DUPLICATE_RUN_CHECK(p_date IN DATE) RETURN BOOLEAN IS
v_count NUMBER(10);
BEGIN
SELECT count(*) into v_count FROM ACCOUNT_TXN WHERE TXN_DESC='INTEREST' AND
TXN_TYPE='C' AND TO_CHAR(TXN_TIMESTAMP,'DD-MON-YYYY')=TO_CHAR(sysdate,'DD-MON-YYYY') AND ROWNUM<=1;

IF v_count=1 THEN 
RETURN TRUE;
ELSE 
RETURN FALSE;
END IF;
END DUPLICATE_RUN_CHECK;

/* Procedure to get periodic interest of whole quarter for a customer.*/
PROCEDURE TRANSACTION_CALCULATION(p_acct_no NUMBER,p_cust_id IN NUMBER,p_cust_transaction OUT t_transaction)
IS
v_t_txn_rec t_transaction;

v_date TIMESTAMP default SYSDATE;
v_quarter_first_date TIMESTAMP; 
v_quarter_last_date TIMESTAMP;

BEGIN

SET_QUARTER(v_date,v_quarter_first_date,v_quarter_last_date);

SELECT TXN_ACCT_NO,TXN_TIMESTAMP,TXN_TYPE,TXN_AMOUNT,TXN_ACCT_BAL,0,0,0 BULK COLLECT INTO v_t_txn_rec FROM ACCOUNT_TXN WHERE TXN_ACCT_CUSTID = p_cust_id 
AND TXN_ACCT_TYPE=1
AND TXN_TIMESTAMP>=v_quarter_first_date
AND TXN_TIMESTAMP<=v_quarter_last_date
ORDER BY TXN_TIMESTAMP;

FOR i IN v_t_txn_rec.FIRST..v_t_txn_rec.LAST
LOOP
IF v_t_txn_rec(i).v_txn_type='C' THEN
v_t_txn_rec(i).v_balance:= v_t_txn_rec(i).v_txn_acct_bal - v_t_txn_rec(i).v_txn_amount;
ELSE
v_t_txn_rec(i).v_balance:= v_t_txn_rec(i).v_txn_acct_bal + v_t_txn_rec(i).v_txn_amount;
END IF;

IF v_t_txn_rec.PRIOR(i) IS NULL THEN
v_t_txn_rec(i).v_no_of_days:=(to_date(to_char(v_t_txn_rec(i).v_txn_date,'DD-MM-YYYY')) - to_date(to_char(v_quarter_first_date,'DD-MM-YYYY')));
ELSE
v_t_txn_rec(i).v_no_of_days:=(to_date(to_char(v_t_txn_rec(i).v_txn_date,'DD-MM-YYYY')) - to_date(to_char(v_t_txn_rec(v_t_txn_rec.PRIOR(i)).v_txn_date,'DD-MM-YYYY')));
END IF;

v_t_txn_rec(i).v_interest_amt:=(v_t_txn_rec(i).v_balance)*(v_t_txn_rec(i).v_no_of_days)*INTEREST_RATE_PER_DAY(v_t_txn_rec(i).v_txn_date);

dbms_output.put_line(v_t_txn_rec(i).v_txn_acct_no||' '||v_t_txn_rec(i).v_txn_date||' '||
v_t_txn_rec(i).v_txn_type||' '||v_t_txn_rec(i).v_txn_amount||' '||v_t_txn_rec(i).v_txn_acct_bal||' '||
v_t_txn_rec(i).v_balance||' '||v_t_txn_rec(i).v_no_of_days||' '||v_t_txn_rec(i).v_interest_amt);


p_cust_transaction(i).v_txn_acct_no:=v_t_txn_rec(i).v_txn_acct_no;
p_cust_transaction(i).v_txn_date:=v_t_txn_rec(i).v_txn_date;
p_cust_transaction(i).v_txn_type:=v_t_txn_rec(i).v_txn_type;
p_cust_transaction(i).v_txn_amount:=v_t_txn_rec(i).v_txn_amount;
p_cust_transaction(i).v_txn_acct_bal:=v_t_txn_rec(i).v_txn_acct_bal;
p_cust_transaction(i).v_balance:=v_t_txn_rec(i).v_balance;
p_cust_transaction(i).v_no_of_days:=v_t_txn_rec(i).v_no_of_days;
p_cust_transaction(i).v_interest_amt:=v_t_txn_rec(i).v_interest_amt;
 
END LOOP;


EXCEPTION
/*When there is no transaction done by a customer during a quarter then the interest will be calculated based on previous balance.*/
WHEN VALUE_ERROR THEN
SELECT ACCT_BAL INTO v_t_txn_rec(0).v_balance FROM ACCOUNT WHERE ACCT_NO=p_acct_no AND ACCT_CUST_ID=p_cust_id;


v_t_txn_rec(0).v_no_of_days:=(to_date(to_char(v_quarter_last_date,'DD-MM-YYYY')) - to_date(to_char(v_quarter_first_date,'DD-MM-YYYY')))+1;
v_t_txn_rec(0).v_interest_amt:=(v_t_txn_rec(0).v_balance)*(v_t_txn_rec(0).v_no_of_days)*INTEREST_RATE_PER_DAY(v_quarter_last_date);

p_cust_transaction(0).v_txn_acct_no:=p_acct_no;
p_cust_transaction(0).v_txn_date:=v_quarter_last_date;
p_cust_transaction(0).v_txn_type:='C';
p_cust_transaction(0).v_txn_amount:=v_t_txn_rec(0).v_interest_amt;
p_cust_transaction(0).v_txn_acct_bal:=v_t_txn_rec(0).v_balance +v_t_txn_rec(0).v_interest_amt;
p_cust_transaction(0).v_balance:=v_t_txn_rec(0).v_balance;
p_cust_transaction(0).v_no_of_days:=v_t_txn_rec(0).v_no_of_days;
p_cust_transaction(0).v_interest_amt:=v_t_txn_rec(0).v_interest_amt;

END TRANSACTION_CALCULATION;

/* Final procedure to sum the interest of all period of a customer and credit it to repective account.*/
PROCEDURE credit_interest IS
v_txn_temp t_transaction;
v_sum_interest NUMBER(15,7):=0;
v_current_balance NUMBER(15,7);
CURSOR c_cust_id IS 
SELECT ACCT.ACCT_NO,ACCT.ACCT_CUST_ID FROM ACCOUNT ACCT
WHERE ACCT.ACCT_TYPE = 1
AND ACCT.ACCT_STATUS='A'
GROUP BY
ACCT.ACCT_NO,
ACCT.ACCT_CUST_ID;

ALREADY_EXEC EXCEPTION;				/*FOR EXECUTING THE PROGRAM ONLY ONCE.*/
NOT_TODAY EXCEPTION;    	/*FOR EXECUTING THE PROGRAM ONLY ON QUARTER END*/
BEGIN

/*Check if it is quarter end or not. */
IF TO_CHAR(SYSDATE,'DD-MON-YY') NOT IN('31-MAR-'||TO_CHAR(SYSDATE,'YY')
 ,'30-JUN-'||TO_CHAR(SYSDATE,'YY'),'30-SEP-'||TO_CHAR(SYSDATE,'YY'),
 '31-DEC-'||TO_CHAR(SYSDATE,'YY')) THEN 
  RAISE NOT_TODAY;
END IF;

/*Check if already executed */
IF DUPLICATE_RUN_CHECK(SYSDATE) THEN
 RAISE ALREADY_EXEC;
END IF;

FOR v_customer IN c_cust_id
LOOP
v_sum_interest:=0;
TRANSACTION_CALCULATION(v_customer.ACCT_NO,v_customer.ACCT_CUST_ID,v_txn_temp);
  FOR i IN v_txn_temp.FIRST..v_txn_temp.LAST
  LOOP
   v_sum_interest:=v_sum_interest+v_txn_temp(i).v_interest_amt;
  END LOOP;
IF v_sum_interest<10 THEN
v_sum_interest:=0;
ELSE
v_sum_interest:=v_sum_interest;
END IF;

dbms_output.put_line(v_customer.ACCT_NO||' '||v_customer.ACCT_CUST_ID||' '||v_sum_interest);

SELECT ACCT_BAL INTO v_current_balance FROM ACCOUNT WHERE ACCT_NO=v_customer.ACCT_NO AND ACCT_CUST_ID=v_customer.ACCT_CUST_ID;

INSERT INTO ACCOUNT_TXN(TXN_ID,TXN_ACCT_NO,TXN_ACCT_TYPE,TXN_ACCT_CUSTID,TXN_TIMESTAMP,TXN_DESC,TXN_TYPE,TXN_AMOUNT,TXN_ACCT_BAL)
VALUES(TRANSIDSEQ.nextval,v_customer.ACCT_NO,1,v_customer.ACCT_CUST_ID,SYSTIMESTAMP,'INTEREST','C',v_sum_interest,(v_current_balance+v_sum_interest));
DBMS_OUTPUT.PUT_LINE('The Interest amount ' || v_sum_interest || ' has been added to account');

UPDATE ACCOUNT SET ACCT_BAL = (v_current_balance+v_sum_interest) WHERE ACCT_NO = v_customer.ACCT_NO;
DBMS_OUTPUT.PUT_LINE('The current balnce of account ' || v_customer.ACCT_NO || ' is ' || (v_current_balance+v_sum_interest));
commit;

END LOOP;

DBMS_OUTPUT.PUT_LINE('The script has been executed successfully and the interest has been credited to active savings accounts.');

EXCEPTION 
  WHEN  ALREADY_EXEC THEN
  DBMS_OUTPUT.PUT_LINE('The process has been already executed.');   
  WHEN NOT_TODAY THEN
  DBMS_OUTPUT.PUT_LINE('Today is not quarter end.');   
END credit_interest;

END BANK_ACC_INTEREST_CALC;
/
