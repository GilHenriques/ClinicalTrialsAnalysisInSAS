/* Import patients table - Assignment 1 */ 
filename patfile '/home/u59181127/sasuser.v94/SimplestGuideClinicalTrialsAnalysisInSAS/Patients.xlsx';

proc import datafile = patfile
	dbms = xlsx
	out = WORK.patients replace;
	getnames = yes;
run;

/* Calculate patients' age - Assignment 2 */
data patients;
	set patients;
	format dob1 date9.;
	
	dob = compress(cat(Month, '/', Day, '/', Year));
	dob1 = input(dob, mmddyy10.);
	
	Age = (today() - dob1) /365;
run;

/* Create summary stats - Assignment 3 */
proc sort data = patients;
	by sex;
run;

proc means data = patients;
	var age;
	output out = pat_age;
run;

proc means data = patients;
	var age;
	by sex;
	output out = pat_sex;
run;