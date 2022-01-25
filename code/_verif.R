library(tidyverse)

# Load dataset
warblers = read_csv("data/warblers_dataset.csv")

# Check the dataset
warblers

warblers %>%
  select(1:3) %>%
  summary()

warblers %>%
  select(starts_with("sp")) %>%
  summary()

warblers %>%
  select(starts_with("wc")) %>%
  select(1:10) %>%
  summary()

warblers %>%
  select(starts_with("wc")) %>%
  select(-c(1:10)) %>%
  summary()

warblers %>%
  select(starts_with("lc")) %>%
  summary()

# Check the glossary
glossary = read_csv("data/warblers_glossary.csv")
print(glossary, n = Inf)
nrow(glossary) == (ncol(warblers) - 3)
all(glossary$variable == names(warblers)[-c(1:3)])
