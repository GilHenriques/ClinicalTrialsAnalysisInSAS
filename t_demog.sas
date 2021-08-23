/* Import demography table */
filename demfile '/home/u59181127/sasuser.v94/SimplestGuideClinicalTrialsAnalysisInSAS/demog.xls';

proc import datafile = demfile
	dbms = xls
	out = WORK.demog replace;
	getnames = yes;
run;

/************/
/************/

/* Section 1: summary stats for age */
data demog1;
	set demog;
	format dob1 date9.; *we will be creating this variable below;
	
	dob = compress(cat(month, '/', day, '/', year)); *create DOB variable, remove trailing and leading spaces;
	dob1 = input(dob, mmddyy10.); *convert to SAS date;
	
	age = (diagdt - dob1)/365; *diagnosis date minus DOB;

	output; * Explicit output: for each observation, we add a new row for which treatment = 2.;
	trt = 2;* this is because we want our table to have one column for placebo (0), ;
	output; * one for treatment (1) and one for all patients (2).;
run;

proc sort data = demog1;
	by trt; * sort by treatment so we can use the by statement later;
run;

proc means data = demog1 noprint; *once we create the "agestats" dataset, we no longer need the procmeans report;
	var age;
	output out = agestats;
	by trt;
run;

data agestats;
	set agestats;
	length value $10.; *we need enough space for accommodating the gender and race percentages: e.g., 30 (10.2%);
	ord = 1; * age will come first in the final table;
	
	
	if _stat_ = 'N' then do; subord = 1; value = strip(put(age, 8.)); end; 
	*the do-end statement is in order to provide the ordering in which we want these rows to appear in the final dataset;
	else if _stat_ = 'MEAN' then do; subord = 2; value = strip(put(age, 8.1)); end;
	else if _stat_ = 'STD' then do; subord = 3; value = strip(put(age, 8.2)); end;
	else if _stat_ = 'MIN' then do; subord = 4; value = strip(put(age, 8.1)); end;
	else if _stat_ = 'MAX' then do; subord = 5; value = strip(put(age, 8.1)); end;

	rename _stat_ = stat; * later on we will want to stack the age, race and gender dataset. So we will need the variable column to have the same name for all three.;
	drop _type_ _freq_ age;
run;


/************/
/************/

/* Section 2: summary stats for sex */
proc format;
	value genfmt 
	1 = 'Male'
	2 = 'Female'; * create a custom format for sex;
run;

data demog2;
	set demog1;
	sex = put(gender, genfmt.);
run;

proc freq data = demog2 noprint;
	table trt * sex / outpct out = genderstats;
run;

data genderstats;
	set genderstats;
	value = cat(count, " (", strip(put(round(pct_row, 0.1), 8.1)), "%)");
	ord = 2;
	
	*reorder variable, note than we can reorder sex before creating it;
	if sex = 'Male' then subord = 1;
	else subord = 2;
	
	rename sex = stat;
	drop count percent pct_row pct_col;
run;

/************/
/************/

/* Section 3: summary stats for race */
proc format;
	value racefmt
	1 = 'White'
	2 = 'Black'
	3 = 'Hispanic'
	4 = 'Asian'
	5 = 'Other'; * create a custom format for sex;
run;

data demog3;
	set demog2;
	racec = put(race, racefmt.);
run;

proc freq data = demog3 noprint;
	table trt * racec / outpct out = racestats;
run;

data racestats;
	set racestats;
	value = cat(count, " (", strip(put(round(pct_row, 0.1), 8.1)), "%)");
	ord = 3;
	
	if racec = 'Asian' then subord = 1;
	else if racec =  'Black' then subord = 2;
	else if racec =  'Hispanic' then subord = 3;
	else if racec =  'White' then subord = 4;
	else if racec =  'Other' then subord = 5;
		
	rename racec = stat;
	drop count percent pct_row pct_col;
run;

/************/
/************/

/* Consolidate all datasets into a single one */
data allstats;
	set agestats genderstats racestats;
run;

/* Transpose data */
proc sort data = allstats;
	by ord subord stat;
run; 

proc transpose data = allstats out = t_allstats prefix = _; *since the id variable is numeric (trt), we need to add a prefix so it can become column names;
	var value;
	id trt; 
	by ord subord stat;
run;

data final; * in the column stat, we will add new rows: Age, Gender, and Race. These will appear right at the beginning of their respective sections ;
	length stat $30.;
	set t_allstats;
	by ord subord;
	output;
	if first.ord then do;
		if ord = 1 then stat = 'Age (years)';
		if ord = 2 then stat = 'Gender';
		if ord = 3 then stat = 'Race';
		subord = 0;
		_0 = "";
		_1 = "";
		_2 = "";
		output;
	end;
run;

proc sort data = final;
	by ord subord;
run;

/* Obtain sample sizes for each treatment */
proc sql noprint;
	select count(*) into :placebo from demog1 where trt = 0;
	select count(*) into :active from demog1 where trt = 1;
	select count(*) into :total from demog1 where trt = 2;
quit;

%let placebo = &placebo; * I'm not sure what this bit does. Teacher says it removes leading spaces from the variables, but I don't see any difference when I run the code without these 3 lines of code.;
%let active = &active;
%let total = &total;

/* Build final report */
title 'Table 1.1';
title2 'Demographic and Baseline Characteristics by Treatment Group';
title3 'Randomized Population';
footnote 'Note: Percentages are based on the number of non-missing values.';
proc report data = final split = '|'; * split option: identifies newline character;
	columns ord subord stat _0 _1 _2;
	define ord / noprint order;
	define subord / noprint order;
	define stat / display width = 50 "";
	define _0 / display width = 30 "Placebo| (N = &placebo)";
	define _1 / display width = 30 "Active Treatment|(N = &active)";
	define _2 / display width = 30 "All Patients|(N = &total)";
run;


