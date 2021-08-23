/* Import demography table */
filename demfile '/home/u59181127/sasuser.v94/SimplestGuideClinicalTrialsAnalysisInSAS/project-demog.xlsx';

proc import datafile = demfile
	dbms = xlsx
	out = WORK.demog replace;
	getnames = yes;
run;

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
	rename _stat_ = stat;
run;

data agestats;
	length stat $18.;
	length value $10.; *we need enough space for accommodating the gender and race percentages: e.g., 30 (10.2%);
	set agestats;
	ord = 1;
	
	if stat = 'N' then do; subord = 1; value = strip(put(age, 8.)); end;
	if stat = 'MEAN' then do; subord = 2; stat = 'Mean'; value = strip(put(age, 8.1)); end;
	else if stat = 'STD' then do; subord = 3; stat = 'Standard Deviation'; value = strip(put(age, 8.2)); end;
	else if stat = 'MIN' then do; subord = 4; stat = 'Minimum'; value = strip(put(age, 8.1)); end;
	else if stat = 'MAX' then do; subord = 5; stat = 'Maximum'; value = strip(put(age, 8.1)); end;
	
	stat = strip(stat);
	
	drop _type_ _freq_ age;
run;

/* Section 2: summary stats for age group */
data demog2;
	set demog1;
	length ageg $14.;
	
	if age <= 18 then ageg = "<= 18 years";
	else if 18 < age < 65 then ageg = "18 to 65 years";
	else if age >= 65 then ageg = ">= 65 years";
run;

proc freq data = demog2 noprint;
	table trt * ageg / outpct out = agegstats;
run;

data agegstats;
	set agegstats;
	value = cat(count, " (", strip(put(round(pct_row, 0.1), 8.1)), "%)");
	ord = 2;
	
	if ageg = '<= 18 years' then subord = 1;
	else if ageg = "18 to 65 years" then subord = 2;
	else subord = 3;
	
	rename ageg = stat;
	drop count percent pct_row pct_col;
run;

/* Section 3: summary stats for sex */
proc format;
	value genfmt 
	1 = 'Male'
	2 = 'Female'; * create a custom format for sex;
run;

data demog3;
	set demog2;
	sex = put(gender, genfmt.);
run;

proc freq data = demog3 noprint;
	table trt * sex / outpct out = genderstats;
run;

data genderstats;
	set genderstats;
	value = cat(count, " (", strip(put(round(pct_row, 0.1), 8.1)), "%)");
	ord = 3;
	
	*reorder variable, note than we can reorder sex before creating it;
	if sex = 'Male' then subord = 1;
	else subord = 2;
	
	rename sex = stat;
	drop count percent pct_row pct_col;
run;

/* Section 4: summary stats for race */
proc format;
	value racefmt
	1 = 'White'
	2 = 'Black'
	3 = 'Hispanic'
	4 = 'Asian'
	5 = 'Other'; * create a custom format for sex;
run;

data demog4;
	set demog3;
	racec = put(race, racefmt.);
run;

proc freq data = demog4 noprint;
	table trt * racec / outpct out = racestats;
run;

data racestats;
	set racestats;
	value = cat(count, " (", strip(put(round(pct_row, 0.1), 8.1)), "%)");
	ord = 4;
	
	if racec = 'Asian' then subord = 1;
	else if racec =  'Black' then subord = 2;
	else if racec =  'Hispanic' then subord = 3;
	else if racec =  'White' then subord = 4;
	else if racec =  'Other' then subord = 5;
		
	rename racec = stat;
	drop count percent pct_row pct_col;
run;

/* Consolidate all datasets into a single one */
data allstats;
	set agestats agegstats genderstats racestats;
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

/* Add category names */
data final; * in the column stat, we will add new rows: Age, Gender, and Race. These will appear right at the beginning of their respective sections ;
	length stat $30.;
	set t_allstats;
	by ord subord;
	output;
	if first.ord then do;
		if ord = 1 then stat = 'Age (years)';
		if ord = 2 then stat = 'Age groups';
		if ord = 3 then stat = 'Gender';
		if ord = 4 then stat = 'Race';
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

/* Build final report */
title 'Table 1.1';
title2 'Demographic and Baseline Characteristics by Treatment Group';
title3 'Randomized Population';
footnote 'Note: Percentages are based on the number of non-missing values in each treatment group.';
proc report data = final split = '|'; * split option: identifies newline character;
	columns ord subord stat _0 _1 _2;
	define ord / noprint order;
	define subord / noprint order;
	define stat / display width = 50 "";
	define _0 / display width = 30 "Placebo|(N = &placebo)";
	define _1 / display width = 30 "Active Treatment|(N = &active)";
	define _2 / display width = 30 "All Patients|(N = &total)";
run;