# Tailoring statement and criticality classification

SPSCRING-DOC-TAIL. Written by Elena Russo, the supplier's project manager. A proposal agreed at the SRR; the category is the customer's
to confirm (SPSCRING-RID-SRR-001).

## 1 Purpose

SPSCring is documented after ECSS-E-ST-40C Rev.1 and ECSS-Q-ST-80C Rev.2, tailored for what it is: one C source file of 338 lines and
its header, a tier 1 library of the platform with no dependency but the C library. The standards are cited, never copied.

## 2 Starting point

The tailoring of the platform's other libraries (uuid7, kyr_lmdb: their ecss/PAF/TAILORING.md) applies as written for the reviews and
the document set, with the differences of section 4.

## 3 Criticality classification

Proposed: **C**. ECSS-Q-ST-80C Rev.2 6.2.2 gives a software's category from the consequences of its failure on the system that uses it;
the system here is the box, as its customer KYR describes it ([../RB/SSS.md](../RB/SSS.md#4-general-description)).

- A defect of the ring loses or duplicates a connection's descriptor in kyr_host. A lost one leaves one client unanswered until its
  timeout; a duplicated one serves one socket twice, or, after the descriptor's number was reused, serves another client's socket with
  the wrong state: one connection's confidentiality and integrity, not the box's store (the write queue and kyr_lmdb guard it).
- That is a major degradation of the box's service, not its loss: category C. Not D, because the front door of every box runs through
  it and a misrouted socket is a disclosure; not B, because no stored record and no other client's session is lost with it.
- The team of SPSCRING (nine people in the rms) holds more independence than category C asks: the author of every item is never its
  approver, the configuration manager who freezes a baseline never approves it.

## 4 Differences

| Clauses | Disposition | Why |
|---|---|---|
| E-40 5.2 (requirements baseline) | performed by the customer | KYR writes the SSS, the IRD and the statement of work (RB/), from kyr_host's code |
| E-40 5.3 (management plans: SDP, SRevP, SCMP) | covered by the package | the reviews are the rms's, each baseline frozen by one person and approved by another; the configuration is git and the rms baselines; no separate plan |
| E-40 5.4 to 5.6 (TS, design, validation) | performed | SRS, ICD, SDD, SUM, API reference, SVS |
| E-40 5.8 (verification) | performed | SVR, the release pipeline's run at the release commit as evidence |
| E-40 5.7 (acceptance) | the customer's | KYR accepts at the QR and pins the release |
| Q-80 7 (product quality) | by the pipeline's gates | 100 % lines and branches, zero warnings, the hardening check, the sanitizers and ThreadSanitizer |

## 5 What the package claims

The SRR, PDR, CDR and QR are held in the rms (project SPSCRING), each closed by its baseline at the release commit 0ad84dc1 (1.0.8);
every claim on the code is a reference to its lines at that commit.
