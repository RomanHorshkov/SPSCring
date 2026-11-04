# Statement of work: the ring for the platform

SPSCRING-DOC-SOW. Written by Oliver Hughes for the customer (KYR, the platform), addressed to the supplier of SPSCring (the team of
project SPSCRING). Part of the requirements baseline (ECSS-E-ST-40C Rev.1 5.2), agreed at the SRR.

## 1 Scope

The supplier develops, verifies, delivers and maintains SPSCring, the single-producer single-consumer ring the platform's host uses to
hand each accepted connection to its operator, to the requirements of the SSS ([SSS.md](SSS.md#5-requirements)) and the IRD
([IRD.md](IRD.md#5-interface-requirements)).

## 2 Work to be performed

1. Keep the library and its interface: app/spscring.h and app/spscring.c, their ABI gated (abi/layout.txt).
2. Specify it: an SRS and an ICD derived from this requirements baseline, after ECSS-E-ST-40C Rev.1 Annexes D and E.
3. Design it: an SDD after Annex F, the decisions recorded, an API reference generated from the code, a user manual after Annex H.
4. Verify it: an SVS after Annex L, the release pipeline of kyr-build's profiles at the release commit, the thread sanitizer included;
   an SVR after Annex M with the evidence.
5. Hold the reviews SRR, PDR, CDR and QR with the customer, each closed by a baseline frozen by the supplier's configuration manager
   and approved by another person.
6. Deliver the Debian packages libspscring and libspscring-dev through the platform's release train, pinned by SHA-256.

## 3 Deliverables

| Deliverable | When |
|---|---|
| The requirements baseline agreed (this document, the SSS, the IRD) | SRR |
| SRS, ICD, SDD (architecture) | PDR |
| SDD (detailed), API reference, SUM, SVS; the first runs | CDR |
| SVR; the release's packages | QR |

## 4 Tailoring and category

The supplier proposes the tailoring and the category ([../PAF/TAILORING.md](../PAF/TAILORING.md#3-criticality-classification)); the
customer confirms the category from the platform's analysis.

## 5 Acceptance

The customer accepts a release at the QR when every case of the SVS has passed at the release commit, and takes it into the platform
by pinning it after the platform's own pipeline passes with it.
