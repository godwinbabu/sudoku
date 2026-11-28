# Research notes: teaching and bedtime design

This file holds the evidence behind the hint, difficulty and Night design. The rules themselves are in CODESPEC (sections 2.2, 6.3, 11 and 12) and HINT_STRATEGIES.md. Figures come from the sources linked below. Some are small studies, so treat them as guides.

## Summary

- Four tiers of about 38 techniques cover what players meet. Singles alone solve most easy puzzles.
- Difficulty depends on how many moves are open at each step, not only on the hardest technique.
- Techniques that assume one solution are unsafe on puzzles with more than one.
- A graduated hint helps learning. A hint that gives the answer at once invites misuse, so help fades as skill grows.
- Total light matters more for sleep than colour tint. People differ widely, and older eyes need more contrast.

## Which techniques to teach

Solvers and rating tools agree on the broad order, from singles through subsets, fish and wings to chains. They disagree on single steps. One scale rates a Hidden Single in a box as easier than a Naked Single. Another scale reverses that. A rating tool with no rule for Skyscraper, W-Wing or coloring sees them only as long chains, so it rates puzzles that use them too hard.

Players need fewer techniques than the full catalogue. A self-reported study of one site's generator found that singles alone finished 192 of 200 Easy boards and 177 of 200 Hard boards. The other Hard boards needed only Pointing or Claiming. On 5,000 Evil boards, the techniques needed most were almost locked sets (2,761 boards), W-Wing (1,769) and XY-Wing (1,743). Jellyfish was needed in only 7. Of 345 Finned X-Wing moves, only 12 had no simpler option ([source](https://sudoku-online-puzzles.com/blog/sudoku-techniques/)). The data is not peer reviewed. It still supports teaching W-Wing and XY-Wing early, and treating Jellyfish, Remote Pairs and Sue de Coq as footnotes.

Some ideas gate whole families of techniques, so each gets a short concept lesson: candidate, strong link, bivalue cell and almost locked set. No tested four-tier curriculum exists in the literature. The tiers in HINT_STRATEGIES.md are a synthesis.

## Difficulty

The number of moves open at each step affects difficulty as much as the hardest technique does. A grade that counts only technique names misses this. A human-model metric in the research correlates at r = 0.95 with real solve times. The number of givens correlates at about 0.25 ([Pelánek, arXiv 1403.7373](https://ar5iv.labs.arxiv.org/html/1403.7373)). A good Easy puzzle is one with many easy moves at once, not only a puzzle that needs singles.

## Uniqueness techniques

Unique Rectangles, BUG+1, and Hidden and Avoidable Rectangles all assume the puzzle has exactly one solution. The rules of Sudoku do not allow a solver to assume it ([Sudopedia: Uniqueness Controversy](http://sudopedia.enjoysudoku.com/Uniqueness_Controversy.html)). An imported puzzle may have two solutions. On such a puzzle, a Unique Rectangle hint can remove the solution the app stored. So the app counts solutions on import, stopping at 2, and turns off this family when the count is not 1 (CODESPEC 2.1). On such a puzzle, Check and Reveal also have no single correct answer.

## Learning from hints

- Help abuse: in one tutoring study, students misused hints on 36% of actions (14% when rapid repeats count once). The figure comes from secondary summaries ([LearnLab](https://learnlab.org/research/wiki/index.php/Help_abuse)).
- A hint that gives the answer is not always bad. When the student reads it, it works as a worked example ([Shih, Koedinger and Scheines 2008](https://www.cmu.edu/dietrich/philosophy/docs/scheines/Shih_Koedinger_Scheines_2008_EDM.pdf)).
- Fading: in two experiments, adaptive fading beat fixed fading, and both beat no examples. Full worked examples can hurt experts. This is called the expertise reversal effect ([Salden et al.](https://repositories.cdlib.org/content/qt27j4x4r8/qt27j4x4r8.pdf?t=op2jmj)).
- Producing an answer yourself improves memory (effect size about 0.40). Testing yourself does too (about 0.50) ([Frontiers in Psychology 2018](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2018.01483/pdf)).
- Skill decay: a half-life model of recall, 2^(−days/half-life), nearly halved the prediction error of a simpler scheme in a large language-learning study ([Settles and Meeder 2016](https://preview.aclanthology.org/fix_video/P16-1174.pdf)).
- No study covers hint ladders in puzzle games. All of this transfers from math and geometry tutors.

These findings shaped the hint card (three steps, the board changes only on the player's choice), the mastery credits and the review drills in CODESPEC 6.3.1 and 12.

## Light and sleep

- In a small inpatient study (n = 12), four hours of tablet reading each night for five nights delayed the body clock and suppressed melatonin, compared with a printed book ([Chang et al. 2015](https://pubmed.ncbi.nlm.nih.gov/25535358/)). That dose is far larger than a 15-minute puzzle.
- A phone's colour-shift mode showed no sleep benefit in 167 young adults ([Duraccio et al. 2021](https://gwern.net/doc/zeo/2021-duraccio.pdf)).
- An expert consensus found that cutting short-wavelength light removes only about 50% of its effect on the body clock. It recommends dimming as well, and 1 lux or less of melanopic light (the light that affects the body clock) in the sleep room ([Brown et al. 2022](https://journals.plos.org/plosbiology/article?id=10.1371/journal.pbio.3001571)).
- People differ. The light level that halved melatonin ranged from 6 to 350 lux across 55 young adults ([Phillips et al. 2019](https://pmc.ncbi.nlm.nih.gov/articles/PMC6575863)).

The design follows. Use true black, so OLED pixels are off. Dim the lit pixels. Treat warmth as a comfort setting and never as a sleep claim. Let each person tune the settings.

## Older eyes

A typical 60-year-old's retina gets about one third of the light a 20-year-old's gets, because of smaller pupils and a yellowing lens ([Lighting Research Center](https://www.lrc.rpi.edu/programs/lightHealth/AARP/healthcare/lightingOlderAdults/agingEye.asp)). Contrast sensitivity starts to fall around age 40–50, and falls further in dim light ([summary](https://laurenscharff.com/research/agecontrast.html)). Faint text slows older readers more than younger ones ([PMC6233613](https://pmc.ncbi.nlm.nih.gov/articles/PMC6233613/)).

So the same dark room needs a brighter digit, stronger contrast, bolder weights and larger notes for an older player. Dimness and contrast must be separate controls. A single overlay that dims everything by the same factor makes small marks unreadable first.

## Limits of iOS

- An app cannot go below the system brightness floor, cannot read ambient light as a lux value, and cannot turn on Reduce White Point.
- An app can set screen brightness only while it is in the foreground. iOS restores it later ([Apple QA1751](https://developer.apple.com/library/archive/qa/qa1751/_index.html)).
- A deep red can look nearly black to some colour-blind users ([Mantiuk et al. 2009](https://www.cs.ubc.ca/labs/imager/tr/2009/Mantiuk_Night_Viewing)).
- On an OLED screen, light spill scales with lit area. A dark grid lights only a few percent of the pixels. The real risk is a sudden white sheet. No published research covers light reaching a sleeping partner, so the Night rules follow from how light works.

## Open questions

- No study measures light reaching a sleeping partner.
- The speed figures for the solver on a phone are estimates. A benchmark in the test suite checks them.
- The four-tier order has not been tested on learners. Short tests in a dark room with players near age 30 and near 60 would settle the Night defaults faster than more reading.
