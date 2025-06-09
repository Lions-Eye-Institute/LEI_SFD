# Motivation

## For what purpose was the dataset created?

Many analytical methods for assessing glaucomatous progression have been suggested but 
nearly all have been tested on separate datasets that happen to be available to the
developers of the methods and using various definitions of ground truth.
This dataset provides an open source resource on which methods can be 
tested and compared using a common dataset and
with a well defined ground truth.

## Who created the dataset (e.g., which team, research group) and on behalf of which entity (e.g., company, institution, organization)?

Lions Eye Institute, Perth Australia.

## Who funded the creation of the dataset?

Internal funding by Lions Save Sight Foundation, Lions Eye Institute and Curtin University.

# Composition

## What do the instances that comprise the dataset represent (e.g., documents, photos, people, countries)?

Each instance represents testing a single eye over a period of 5 years at 6 monthly intervals and contains
Humphrey Field Analyzer 24-2 visual fields and Spectralis OCT ONH ring scans.

Instances have different levels of measurement noise added ranging from none ("True"), "typical" ("Reliable") to substantial ("Unreliable").

### VF Noise
Perimetric noise is introduced by using simulated measurements of True data using
the Full Threshold (FT, a 4-2 staircase) algorithm as implemented in the Open Perimetry Interface (R package OPI, v3.0)
and using the "SimHenson" mode of simulation in the OPI default parameters and 
with different false positive and false negative response rates.
In addition, for some instances a value was added to all true values prior to simulation as a "general height" change or "global visit effect" (see [below](#gve)).

### OCT Noise
OCT noise is introduced as the sum of repeatability (within test) and reproducibility (between test) noise 
each sampled from a normal distribution with mean zero and standard deviation 
modelled on the results from [Schrems-Hoesl et al. 2018. "Precision of Optic Nerve Head and 
Retinal Nerve Fiber Layer Parameter Measurements by Spectral-domain Optical Coherence Tomography".](https://doi.org/10.1097/ijg.0000000000000875)
The standard deviation of noise for a sector $i\in[1,6]$ was the 
sum of the between and within values 
$\sigma_i = \sqrt{6\times w_i/100}\times\mu$
with $w_i$ and $\mu$ given in the following table.
For a cpRNFL pixel in sector $i$, noise was drawn from $N(0, \sigma_i\sqrt{n_i})$ where $n_i$ is the number 
of pixels (A-scans) in sector $i$. (Thus $\sum n_i = 768$.)

| | $w_i$<br>Temporal<br>-45:45° |  $w_i$<br>TS<br>46:85° | $w_i$<br>TI<br>86:125° | $w_i$<br>Nasal<br>126:235° | $w_i$<br>NS<br>236:275° | $w_i$<br>NI<br>276:315° | $\mu$<br>All<br>sectors |
---------------------------------------------|:--------:|:------:|:------:|:-------:|:-------:|:--------:|:------:|
Baseline (visit 1) between (reproducibility)| 10| 20| 14| 25| 28|  3|  2.7  |
Baseline (visit 1) within (repeatability)   | 15| 17| 15| 17| 21| 15|  2.2  |
Followup (visits 2-10) between              | 12| 21| 16| 18| 25|  8|  2.5  |
Followup (visits 2-10) within               | 26| 13|  9| 24| 15| 13|  0.79 |

Before adding the noise to the "true" OCT, it was smoothed using the mean of a sliding-window of width 151 pixels (A-scans).
Any "noise + oct" values that fell below the floor of 40 micros was sampled from $\max(30, N(40, \sigma_f))$ 
where $\sigma_f$ was 5 for visit 1 (baseline) and 2 for other visits (2-10). 
This vector of "floor noise" was smoothed with sliding window of size 20 pixels.
Finally, the "oct + noise" is rounded to the nearest integer.
See `generate.r` for code.

### <a href = "gve"></a>Visit specific noise

To account for some other real world effects in the perimetric data, a Global Visit Effect (GVE) is
added to some instances.
This might include factors like
  * poor/different operator performance, eg bad patient instruction, negligent perimetric monitoring, etc;
  * external distractions, eg fire alarms, noisy test rooms, lighting, etc; or
  * patient fatigue, eg long waiting times, repeated tests, etc.

The GVE is an addition of a value sampled from the set $\{-2, +2\}$ with equal chance and is added to **one** visit in the sequence of 10 for each eye.
Thus be careful when using the GVE instances with less than 10 visits; there may
be no GVE present.

No GVE is used for OCT data.

### Ageing

There are no aging effects added to the VF or OCT data in these datasets. 
The slopes of progression for the VF data 
were derived from real HFA data after correcting for ageing at a rate of 1 dB per decade. 
The slopes of OCT
progression were taken as is from the real data without any age adjustment.
The date range of the real series spanned [2.5, 10.7] years 
(median: 5.0 IQR: [ 4.2, 5.9]), so OCT ageing is at most about 1 micron.
([Chauhan et al. 2020. "Differential Effects of Aging in the Macular Retinal Layers, 
Neuroretinal Rim, and Peripapillary Retinal Nerve Fiber Layer."](https://doi.org/10.1016/j.ophtha.2019.09.013))


## How many instances are there in total (of each type, if appropriate)?

177 eyes from 122 people, 4 types of noise, stable and progressing.

|                      |  n  | False Positive<br>SAP | False Negative<br>SAP | GVE<br>SAP | OCT noise |
|----------------------|:---:|:--------------:|:--------------:|:-------:|:---------:|
|True                  | 177 |                |                |         |           |
|Reliable              | 177 |   3%           |       1%       |         | $N(0, N(\mu, \sigma))$ |
|UnReliable            | 177 |   15%          |       3%       |         | $N(0, N(\mu, \sigma))$ |
|Reliable-GVE          | 177 |   3%           |       1%       | $\pm2$  | $N(0, N(\mu, \sigma))$ |
|UnReliable-GVE        | 177 |   15%          |       3%       | $\pm2$  | $N(0, N(\mu, \sigma))$ |
|Stable Reliable       | 177 |   3%           |       1%       |         | $N(0, N(\mu, \sigma))$ |
|Stable UnReliable     | 177 |   15%          |       3%       |         | $N(0, N(\mu, \sigma))$ |
|Stable Reliable-GVE   | 177 |   3%           |       1%       | $\pm2$  | $N(0, N(\mu, \sigma))$ |
|Stable UnReliable-GVE | 177 |   15%          |       3%       | $\pm2$  | $N(0, N(\mu, \sigma))$ |

where $\mu$ and $\sigma$ are as described in the previous section. 

## What data does each instance consist of? 

 * Eye number (1..177)
 * Person number (1..122)
 * Visit Number
 * 52 Static Automated Perimetry Sensitivity values (dB)
 * 52 Static Automated Perimetry Total Deviations (dB)
 * 768 cpRNFL Thickness values (microns)

In addition, there are two meta data files and one main R script.
 * [person.csv](person.csv) gives the sex and age at final HFA measurement for each person.
 * [xy.csv](xys.csv) gives the (x,y) coordinates of the vf* columns in the data files.
 * [generate.r](generate.r) which will generate similar data sets that can be used for training, determining confidence intervals and so on.

## Is there a label or target associated with each instance?

No. Separate classes of instances are in different input files.

## Is any information missing from individual instances?

No

## Are there recommended data splits (e.g., training, development/validation, testing)?

It is recommended that any data split preserves the order of the ID numbers.
For example, a 60%/20%/20% split of the Reliable data would use Id numbers 1..106/107..142/143..177.

## Are there any errors, sources of noise, or redundancies in the dataset?

All data is synthetically generated to have given rates of progression, hence there is no noise other than that 
deliberately introduced.


## Is the dataset self-contained, or does it link to or otherwise rely on external resources (e.g., websites, tweets, other datasets)?

This dataset is self-contained. 


## Does the dataset contain data that might be considered confidential (e.g., data that is protected by legal privilege or by doctor–patient confidentiality, data that includes the content of individuals’ non-public communications)?

No. The dataset is synthetically derived from real data in ways that cannot be accurately reversed thus contains no private information.


## Does the dataset relate to people?

Yes

## Does the dataset identify any subpopulations (e.g., by age, gender)?

The synthetic data represents glaucomatous eyes of those over age 18.

# Collection Process

## How was the data associated with each instance acquired?

All data is synthetically generated based on real data collected at the Lions Eye Institute Glaucoma clinic over the years 2010 to 2021. 
24-2 SAP data were collected with the Humphrey Field Analyzer (Zeiss) and thus synthetic data represents fields collected on that device.
Similarly, the OCT data is based on data collected with the Spectralis OCT device (Heidelberg Engineering) at the same clinic, so represents
data collected by that device in a tertiary glaucoma clinic.

## What mechanisms or procedures were used to collect the data?

All tests were 24-2 white-on-white Goldmann stimulus size III exams, performed with either a Swedish Interactive Thresholding Algorithm (SITA, Standard or Fast) strategy. 

All OCT scans used the cpRNFL ring scan with the number of eyes with each protocol given 
in the following table.

| Spectralis Protocol  |  Diameter  | Number |
|----------------------|:---:|--------------:|
  OCT Circle Scan  | 3.3  | 4  |
  OCT Circle Scan  | 3.4  | 25 |
  OCT Circle Scan  | 3.5  | 50 |
  OCT Circle Scan  | 3.6  | 24  |
  OCT Circle Scan  | 3.7  | 9  |
  OCT Circle Scan  | 3.8  | 3  |
  OCT Circle Scan  | 3.9  | 1 |
  OCT Radial Circle Scan | 3.5 | 47 |


## Who was involved in the data collection process?

This synthetic data is based on real data collected by ophthalmologic technicians working at Lions Eye Institute the as part of routine clinical care.  
The true slopes of progression in each eye and the final VF and OCT was used to generate the synthetic data.

## Over what time frame was the data collected?

The real data was collected between 2010 and 2021 and this data generated in 2025.

## Were any ethical review processes conducted?

All patients consented for their data to be used for research purposes. As this published data set contains no actual real data, no
IRB approval was sought for its publication.

## Did you collect the data from the individuals in question directly, or obtain it via third parties or other sources?

Real data was collected from the clinical information systems directly.

## Were the individuals in question notified about the data collection? 

No.

## Did the individuals in question consent to the collection and use of their data?

Yes.

## If consent was obtained, were the consenting individuals provided with a mechanism to revoke their consent in the future or for certain uses?

No.

## Has an analysis of the potential impact of the dataset and its use on data subjects been conducted?

Yes


# Preprocessing/cleaning/labeling

## Was any preprocessing/cleaning/labeling of the data done?

All data is synthetically generated from extensively filtered real data.


## Was the “raw” data saved in addition to the preprocessed/cleaned/labeled data?

The real data which seeded the production of this synthetic data is not publicly available.

## Is the software used to preprocess/clean/label the instances available?
No


# Uses

## Has the dataset been used for any tasks already?
No.

## Is there a repository that links to any or all papers or systems that use the dataset?
Yes, [LEI github](https://github.com/Lions-Eye-Institute/LEI_SFD)
and some cross linking on 
the [Open Perimetry Initiative](https://openperimetry.org).

## What (other) tasks could the dataset be used for?

Any tasks investigating glaucomatous progression using SAP or OCT ONH scans.


## Is there anything about the composition of the dataset or the way it was collected and preprocessed/cleaned/labeled that might impact future uses?
No

## Are there tasks for which the dataset should not be used?
No attempts should be made to discover the original data on which this synthetic data is based.


# Distribution

## Will the dataset be distributed to third parties outside of the entity?
The dataset is publicly available.

## How will the dataset be distributed (e.g., tarball on website, API, GitHub)?
[LEI github](https://github.com/Lions-Eye-Institute/LEI_SFD)

## What (other) tasks could the dataset be used for?

Any tasks investigating glaucomatous progression using SAP or OCT ONH scans.


## Is there anything about the composition of the dataset or the way it was collected and preprocessed/cleaned/labeled that might impact future uses?

No.

## When will the dataset be distributed?
Early 2025.

## Will the dataset be distributed under a copyright or other intellectual property (IP) license, and/or under applicable terms of use (ToU)?
The dataset will be available for open source use under the 3-Clause BSD license.

## Have any third parties imposed IP-based or other restrictions on the data associated with the instances?
No

## Do any export controls or other regulatory restrictions apply to the dataset or to individual instances? 
No


# Maintenance

## Who will be supporting/hosting/maintaining the dataset?
The dataset will be hosted on GitHub and maintained by LEI staff.

## How can the owner/curator/manager of the dataset be contacted?
Email: [andrew.turpin@lei.org.au](mailto:andrew.turpin@lei.org.au)

## Is there an erratum? 
No

## Will the dataset be updated?
As at March 2025, corrections and additions will be made if necessary.
More eyes may be added in the future.

## If the dataset relates to people, are there applicable limits on the retention of the data associated with the instances?
No

## Will older versions of the dataset continue to be supported/hosted/maintained?
Yes on GitHub.

## If others want to extend/augment/build on/contribute to the dataset, is there a mechanism for them to do so?
Yes: using github.
