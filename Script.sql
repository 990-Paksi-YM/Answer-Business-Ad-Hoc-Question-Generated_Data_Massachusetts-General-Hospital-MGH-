-- data head
select
  *
from
  dqlab-yudha-sample1.Hospital.encounters as e
    inner join dqlab-yudha-sample1.Hospital.organizations as o 
      on e.Organization = o.Id
    inner join dqlab-yudha-sample1.Hospital.patients as pa
      on e.Patient = pa.Id
    inner join dqlab-yudha-sample1.Hospital.payers as py
      on e.Payer = py.Id
    inner join dqlab-yudha-sample1.Hospital.procedures as pr
      on e.Id = pr.Encounter
limit
  10
;

-- 1. How many patients have been admitted or readmitted over time?

  select
    count(distinct PATIENT) as Patient
  from
    dqlab-yudha-sample1.Hospital.encounters
  where
    ENCOUNTERCLASS = 'inpatient'

;

-- for detail in timeline

  select
    extract(MONTH FROM start) as month,
    extract(YEAR FROM start) as year,
    count(distinct PATIENT) as ct
  from
    dqlab-yudha-sample1.Hospital.encounters
  where
    ENCOUNTERCLASS = 'inpatient'
  group by
    1,2
  order by
    2, 1 ASC
;


-- 2. How long are patients staying in the hospital, on average?
with db as (
  select
    e.Id as id,
    e.Patient as pasien,
    case
      when e.start <= p.start then e.start else p.start end as starting,
    case
      when e.stop >= p.stop then e.stop else p.stop end as stoping
  from
    dqlab-yudha-sample1.Hospital.encounters as e
      left join dqlab-yudha-sample1.Hospital.procedures as p
      on e.Id = p.Encounter
),

dbn as (
  select
    db.id,
    db.pasien,
    timestamp_diff(max(db.stoping), min(db.starting), MINUTE) as duration
  from
    db
  group by
    1,2
),

dbd as (
  select
    dbn.id,
    dbn.pasien,
    avg(duration) as avrg
  from
    dbn
  group by
    1,2
),

final as (
  select
    dbd.pasien,
    avg(dbd.avrg) as durationfinal
  from
    dbd
  group by
    1
  order by
    2 DESC
)

select
  avg(final.durationfinal) as avgduration
from
  final

;

-- 3. How much is the average cost per visit?
-- head data
select
  Id,
  Total_Claim_Cost
from
  dqlab-yudha-sample1.Hospital.encounters
limit
  10
;

-- check null data
select
  Id,
  Total_Claim_Cost
from
  dqlab-yudha-sample1.Hospital.encounters
where
  Id is null
;

select
  Id,
  Total_Claim_Cost
from
  dqlab-yudha-sample1.Hospital.encounters
where
  Total_Claim_Cost is null
;
-- look good

-- check duplicate data
select
  Id,
  Total_Claim_Cost,
  count(Id)
from
  dqlab-yudha-sample1.Hospital.encounters
group by
  1, 2
order by
  3 DESC
; -- look good

with db as(
  select
    Id,
    Total_Claim_Cost
  from
    dqlab-yudha-sample1.Hospital.encounters
)

select
  avg(db.Total_Claim_Cost) as avgcostbyvisit
from
  db
;

-- 4. How many procedures are covered by insurance?
-- head data
select
  e.Id,
  e.Total_Claim_Cost
from
  dqlab-yudha-sample1.Hospital.encounters as e
    left join dqlab-yudha-sample1.Hospital.procedures as p
      on e.Id = p.Encounter
where
  p.Encounter is not null
limit
  10

;

with db as (
  select
    p.Code as code,
    e.Total_Claim_Cost as costall
  from
    dqlab-yudha-sample1.Hospital.encounters as e
      left join dqlab-yudha-sample1.Hospital.procedures as p
        on e.Id = p.Encounter
  where
    p.Encounter is not null
    and
    e.Payer_Coverage is not null
)

select
  count(db.code)
from
  db

;

--5 Apakah ada korelasi antara banyaknya prosedur yang dilakukan dengan durasi prosedur dilakukan ?
with db as (
  select
    Description,
    count(*) as ct,
    timestamp_diff(Stop, Start, Minute) as duration
  from
    dqlab-yudha-sample1.Hospital.procedures
  group by
    1, Stop, Start
  order by
    3 DESC
),

db2 as (
  select
    db.Description,
    sum(db.ct) as countofprocedures,
    avg(db.duration) as avgduration_minute
  from
    db
  group by
    1
)

select
  corr(db2.countofprocedures, db2.avgduration_minute)
from
  db2
-- korelasi negatif sangat lemah, hampir tidak ada korelasi sama sekali
;

-- 6. Berapa persentase kunjungan yang memiliki setidaknya satu prosedur medis?
with db as (
  select
    count(distinct e.Id) as id1
  from
    dqlab-yudha-sample1.Hospital.encounters as e
    left join
      dqlab-yudha-sample1.Hospital.procedures as p
        on e.Id = p.Encounter
  where
    p.Code is not null
),

db2 as (
  select
    count(distinct e.Id) as id2
  from
    dqlab-yudha-sample1.Hospital.encounters as e
    left join
      dqlab-yudha-sample1.Hospital.procedures as p
        on e.Id = p.Encounter
)

select
  (db.id1/db2.id2)*100 as prct
from
  db,db2
;

-- 7. Identifikasi prosedur medis yang paling sering dilakukan untuk setiap diagnosis (ReasonCode), 
-- tetapi hanya tampilkan prosedur yang dilakukan minimal 5 kali


-- select diagnose and procedure coloumn also count all
with db as (
  select
    e.ReasonDescription as diagnose,
    p.Description as procedur,
    count(*) as count_of_procedureanddiagnose
  from
    dqlab-yudha-sample1.Hospital.procedures as p
      inner join
        dqlab-yudha-sample1.Hospital.encounters as e
          on p.Encounter = e.Id
  where
    p.Description is not null
    and
    e.ReasonDescription is not null
  group by
    1,2
),

-- count_of_procedure
db2 as (
  select
    db.diagnose as diagnose,
    count(db.diagnose) as count_of_diagnose
  from
    db
  group by
    1
),
-- join all and give row number by diagnose and count_of_procedureanddiagnose DESC
db3 as (
  select
    db.diagnose,
    db.procedur,
    db.count_of_procedureanddiagnose,
    db2.count_of_diagnose,
    row_number() over(partition by db.diagnose order by db.count_of_procedureanddiagnose DESC) as rownumber
  from
    db
      inner join db2
        on db.diagnose = db2.diagnose
  where
    db.count_of_procedureanddiagnose >= 5
)
--  choose the most procedure each diagnose
select
  db3.diagnose,
  db3.procedur,
  db3.count_of_procedureanddiagnose
from
  db3
where
  db3.rownumber = 1
;


-- 7. Identification of patients who had a visit with the same diagnosis within 30 days
-- data coloumn used
with db as (
  select
    Id,
    extract (Year FROM Start) as start_year,
    extract (Month from Start) as start_month,
    extract (Year from Stop) as stop_year,
    extract (Month from Stop) as stop_month,
    Patient,
    ReasonDescription
  from
    dqlab-yudha-sample1.Hospital.encounters
  where
    ReasonDescription is not null
),

-- generate year and month base on max stop and min start
daten as (
SELECT 
  extract (Year from date_month) AS year_,
  extract (Month from date_month) as month
FROM 
  UNNEST(GENERATE_DATE_ARRAY(DATE('2011-01-01'), DATE('2022-02-01'), INTERVAL 1 MONTH)) AS date_month
),

-- merge data reuqired and month year generated
db2 as (
  select
    daten.year_,
    daten.month,
    db.Id,
    db.start_year,
    db.start_month,
    db.stop_year,
    db.stop_month,
    db.Patient,
    db.ReasonDescription
  from
    db
      join
        daten
          on
            daten.year_ between db.start_year and db.stop_year
            and
            daten.month between db.start_month and db.stop_month
),

-- select patient and diagnose and count of diagnose in each month and year who have more than 2 count_of_diagnose
db5 as (
  select
    db2.year_,
    db2.month,
    db2.Patient,
    db2.ReasonDescription as diagnose,
    count(*) as count_of_diagnose
  from
    db2
  group by
    1,2,3,4
  having
    count_of_diagnose >= 2
  order by
    1, 2, 5 DESC
)

select
  count(distinct db5.Patient) as count_of_patient
from
  db5

;



/*

Operation Excellence Department Project:
Emergency Department Lead Time Optimation

Problem Statement: The high waiting time of patients in the emergency department causes patient dissatisfaction

Metric: 
the number of emergency department patients over time
the length of encounter time for emergency department patients over time
the length of time for each procedure performed by emergency department patients over time.

*/

with date_generate as (
  SELECT 
  date_time
FROM 
  UNNEST(GENERATE_TIMESTAMP_ARRAY(TIMESTAMP('2011-01-01 00:00:00'), TIMESTAMP('2022-02-02 00:00:00'), INTERVAL 3 HOUR)) AS date_time
),

a1_numerator as (
  select
    e.Start as Start,
    e.Stop as Stop,
    count(e.Patient) as count_of_patient
  from
    dqlab-yudha-sample1.Hospital.encounters as e
  where
    e.EncounterClass = 'emergency'
  group by
    1,2
),

a2_numerator as (
  select
    e.Start as Start,
    e.Stop as Stop,
    timestamp_diff(e.Stop, e.Start, Minute) as duration_encounter_minute  
  from
    dqlab-yudha-sample1.Hospital.encounters as e
  where
    e.EncounterClass = 'emergency'

),

a3_numerator as (
  select
    p.Start as Start,
    p.Stop as Stop,
    p.Description as procedures,
    timestamp_diff(p.Stop, p.Start, Minute) as duration_per_prosedure_minute
  from
    dqlab-yudha-sample1.Hospital.procedures as p
      inner join
        dqlab-yudha-sample1.Hospital.encounters as e
          on
            p.Encounter = e.Id
  where
    e.EncounterClass = 'emergency'
  group by
    1,2,3
),

a3_deminator as (
  select
    a3n.Start,
    a3n.Stop,
    avg(a3n.duration_per_prosedure_minute) as avg_duration_per_prosedure_minute
  from
    a3_numerator as a3n
  group by
    1,2
)

select
  dt.date_time,
  coalesce(sum(a1n.count_of_patient),0) as count_of_patient,
  coalesce(sum(a2n.duration_encounter_minute),0) as duration_encounter_minute,
  coalesce(sum(a3d.avg_duration_per_prosedure_minute),0) as avg_duration_per_prosedure_minute
from
  date_generate as dt
    left join
      a1_numerator as a1n
        on
          dt.date_time between a1n.Start and a1n.Stop
    left join
      a2_numerator as a2n
        on
          dt.date_time between a2n.Start and a2n.Stop
    left join
      a3_deminator as a3d
        on
          dt.date_time between a3d.Start and a3d.Stop
group by
  1
order by
  dt.date_time ASC

;
