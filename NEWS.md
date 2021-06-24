# Rnssp-rmd-templates

## State Emergency Department template (`state_ed_report`)

<details>

<summary>6/8/2021</summary>
State Emergency Department template available.

</details>

## Text Analysis Interactive Dashboard template (`text_mining`)

<details>

<summary>6/19/2021</summary>
The Text Mining has been updated. This version contains the following updates:

* Users now have a choice to select a syndrome definition from a list of all CCDD categories, subsyndromes, and syndromes that are currently in the system. Users no longer need to manually paste in the query to populate on the Background tab. The input option allows for users to type and search for a definition type and name when knitting with parameters. As done in the combined category fields in ESSENCE, CCDD categories are proceeded by CCDD Category, subsyndromes by Subsyndrome, and syndrome by Syndrome.

* Chief complaint correlation network graph (based on Pearson correlation). Terms are filtered with a correlation greater than 0.15. Opacity of the edges/lines represents the magnitude of correlation. Note that pairs that occur next to each other in the chief complaint are removed in an attempt to avoid identifying term pairs that one would expect to see and that show up in the top 200 bigrams. Also added is a search table below the graph so that users can search for correlations for a term of interest. 

* n-gram trend analysis for chief complaint and discharge diagnosis unigrams and bigrams. The sections of code that generate these have been modified to prevent errors when there are no significant terms identified. 

</details>

<details>
<summary>5/21/2021</summary>
Text Mining template available.
</details>
