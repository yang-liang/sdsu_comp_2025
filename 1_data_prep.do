clear

*** Set your directory paths
global comp2025 "${sdsu_comp}/Comp 2025"
global raw_data  "${comp2025}/ACS/data/raw"
global output_data  "${comp2025}/ACS/data/clean"

use "${raw_data}/usa_00002.dta"

** Keep only waves from 2010 to  (If you want to expand, download ACS from earlier years and adapt the min and max)
 local min=2010
 local max=2015

keep if inrange(year,`min',`max')

* The sample is limited to mothers aged 21-35 whose oldest child was under 18 years old at the time of the Census.

**** Identify children – Restriction: They must be under 18 years old
preserve
keep momloc serial sex age year
keep if inrange(age,0,18)
rename momloc pernum
rename sex sexchild
rename age agechild
sort serial pernum
tempfile children
save `children'
restore

** Keep only mothers aged 21-35
keep if sex==2 & inrange(age,21,35)

preserve

*** Match using family ID, personal ID, and Census year
merge 1:m serial pernum year using "`children'"
keep if _merge==3
drop _merge

**** Generate a unique individual ID
/* Note on strID: This variable is created to optimize computing resources and improve processing speed. 
   If you plan to expand the dataset significantly, consider dropping non-essential variables to save memory. */

gen ID_per = string(serial, "%9.0f") + "_" + string(pernum, "%9.0f") + "_" + string(year, "%9.0f")

keep ID_per sexchild agechild

bysort ID_per (agechild): gen sort = _n 

* Condition: The oldest child must be under 18 years old at the time of the Census.
bys ID_per: egen oldest_child = max(agechild)
drop if inrange(oldest_child,19,25)

reshape wide sexchild agechild, i(ID_per) j(sort)

** Keep only women with at least two children
keep if agechild2 != .

***** Generate Instrumental Variables

gen two_boys = (sexchild1 == 1 & sexchild2 == 1)
gen two_girls = (sexchild1 == 2 & sexchild2 == 2)
gen same_sex = (sexchild1 == sexchild2)

keep two_boys two_girls same_sex ID_per

sort ID_per
tempfile children_instrument
save `children_instrument'

restore

gen ID_per = string(serial, "%9.0f") + "_" + string(pernum, "%9.0f") + "_" + string(year, "%9.0f")

sort ID_per
merge 1:1 ID_per using "`children_instrument'"

** Keep the merged (relevant) sample

keep if _merge==3

** Keep only relevant variables (e.g., ID, indicators, covariates)
keep ID_per two_boys two_girls same_sex labforce uhrswork educ race age sex nchild

*** Generate the variables for the analysis (clean them). Example
tab labforce
gen lfp= (labforce==2)

lab var lfp "Labor Force Participation"

save "${output_data}/main_data.dta",replace