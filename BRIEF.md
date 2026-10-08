# IBM HR Analytics: employee attrition

Public project. Started 2026-10-08.

## Question

What are the top predictors of employee attrition in the IBM HR Analytics training set, and why are they top predictors?

## Data

Kaggle dataset `pavansubhasht/ibm-hr-analytics-attrition-dataset` (the training file, commonly `WA_Fn-UseC_-HR-Employee-Attrition.csv`). Open data. The records are fictional: IBM data scientists created this sample, and it is not data on real employees. Target is `Attrition` (Yes/No). Everything in this project may be public.

## Deliverables

1. Analysis of the top predictors, with why each one ranks where it does, using recursive partitioning (a decision tree in the style of SAS JMP).
2. An interactive app, similar to JMP's recursive partitioning: upload a CSV, show variable importance for all predictors at the current node, and allow a custom split. Publish it publicly on the free shinyapps.io account `jaysha301`.
3. A public GitHub repo under `jaysha301` holding the data, the app, the analysis, and the write-up.
4. A 1 to 2 page narrative summary: the patterns, sourced I/O research on why they matter, and recommendations. More narrative than the Glassdoor one-pager. Iris writes it only after Quinn signs off.

## Team

- Rowan runs the analysis and uses Soup's app.
- Ellis supplies sourced I/O research tied to the predictors Rowan actually finds, and recommendations grounded in that research.
- Quinn reviews data quality and the method before anything is final. Iris does not start the write-up until Quinn signs off.
- Soup builds the app, publishes it publicly, and creates the public GitHub repo.
- GG coordinates and reports to the user.

## Out of scope

Do not treat rate fields that are known artifacts (DailyRate, HourlyRate, MonthlyRate) as real pay without saying so. Do not present a weak classifier as a precise prediction. Recommendations are suggestions from the findings and the research, not tested interventions.
