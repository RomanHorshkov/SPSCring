# The ECSS package of SPSCring

SPSCring 1.0.8 (0ad84dc1daf31dde302bee2fa1d1e5386049e5ec) documented after ECSS-E-ST-40C Rev.1 and ECSS-Q-ST-80C Rev.2, category C
proposed ([PAF/TAILORING.md](PAF/TAILORING.md#3-criticality-classification)). Written by the team of project SPSCRING in the box's
rms; this package is the source of its items, its links and its documents. The standards are cited, never copied.

## Customer and supplier

```text
   KYR (the platform, the customer)                         SPSCRING (the supplier)
   kyr_host 1.5.0: the listener hands each      RB/        TS/  DDF/  DJF/
   accepted socket to an operator's ring   ── SSS, IRD, SOW ─▶  SRS, ICD, SDD, SUM, API, SVS, SVR
                                           ◀── the release 1.0.8, qualified at the QR, pinned in deps.txt
```

The requirements baseline is the customer's: Oliver Hughes writes it in SPSCRING from kyr_host's code ([RB/SSS.md](RB/SSS.md#5-requirements),
[RB/IRD.md](RB/IRD.md#5-interface-requirements), [RB/SOW.md](RB/SOW.md#2-work-to-be-performed)). Every software requirement derives
from it ([TS/SRS.md](TS/SRS.md#5-requirements)). In the rms, SPSCRING hangs under KYR and takes KYR's approved baseline as its input
SPSCRING-INPUT-KYR when KYR holds one.

Who links the library: kyr_host (the hand-off), the box's servers through kyr_host (kyr_server), the platform's train (kyr), and
kyr_rms's tests; all pin 1.0.7, whose code is 1.0.8's.

## Files

| File | What |
|---|---|
| `RB/` | the customer's: SSS, IRD, statement of work, their requirements (`requirements.csv`) |
| `TS/` | SRS, ICD, the requirements, assumptions and interfaces (`requirements.csv`) |
| `DDF/` | SDD, SUM, the components and configuration item, the decisions; `api/` the Doxygen reference (written by the loader) |
| `DJF/` | SVS, SVR, the cases, the results and the runs' logs (`runs/0ad84dc1/`) |
| `PAF/` | the tailoring |
| `diagrams/` | PlantUML: components, the ring's states, push and pop with their ordering, deployment; each rendered to SVG beside it in the rms |
| `rms/` | the project, the cast, the links, the reviews (RIDs, change requests), the sources, the customer's files |
| `tools/package.py` | checks the package (every reference included) and writes the documents' tables |

## The documents

<!-- ecss:table documents -->
| ID | Title | DRD | Review | Path | Written by |
|---|---|---|---|---|---|
| SPSCRING-DOC-PKG | The ECSS package of SPSCring: what it holds and how it maps to the rms | - | SRR | [ecss/README.md](README.md) | Elena Russo |
| SPSCRING-DOC-TAIL | Tailoring statement and criticality classification | - | SRR | [ecss/PAF/TAILORING.md](PAF/TAILORING.md) | Elena Russo |
| SPSCRING-DOC-SSS | Software system specification (SSS): what the platform requires of the ring | ECSS-E-ST-40 Annex B | SRR | [ecss/RB/SSS.md](RB/SSS.md) | Oliver Hughes |
| SPSCRING-DOC-IRD | Interface requirements document (IRD) toward SPSCring | ECSS-E-ST-40 Annex C | SRR | [ecss/RB/IRD.md](RB/IRD.md) | Oliver Hughes |
| SPSCRING-DOC-SOW | Statement of work: the ring for the platform | - | SRR | [ecss/RB/SOW.md](RB/SOW.md) | Oliver Hughes |
| SPSCRING-DOC-SRS | Software requirements specification (SRS) | ECSS-E-ST-40 Annex D | PDR | [ecss/TS/SRS.md](TS/SRS.md) | Luca Romano |
| SPSCRING-DOC-ICD | Interface control document (ICD) | ECSS-E-ST-40 Annex E | PDR | [ecss/TS/ICD.md](TS/ICD.md) | Luca Romano |
| SPSCRING-DOC-SDD | Software design document (SDD) | ECSS-E-ST-40 Annex F | PDR,CDR | [ecss/DDF/SDD.md](DDF/SDD.md) | Emily Clarke |
| SPSCRING-DOC-API | API reference of spscring.h (from the code, by Doxygen) | - | CDR | [ecss/DDF/api/spscring.md](DDF/api/spscring.md) | Emily Clarke |
| SPSCRING-DOC-SUM | Software user manual (SUM) | ECSS-E-ST-40 Annex H | CDR | [ecss/DDF/SUM.md](DDF/SUM.md) | Emily Clarke |
| SPSCRING-DOC-SVS | Software validation specification w.r.t. the TS (SVS) | ECSS-E-ST-40 Annex L | CDR | [ecss/DJF/SVS.md](DJF/SVS.md) | Davide Conti |
| SPSCRING-DOC-SVR | Software verification report (SVR) | ECSS-E-ST-40 Annex M | QR | [ecss/DJF/SVR.md](DJF/SVR.md) | Davide Conti |
<!-- /ecss:table -->

## The people

<!-- ecss:table cast -->
| Person | Roles | Duties |
|---|---|---|
| Elena Russo | project-admin, author | grants the team; writes the package overview and the tailoring; plans the reviews; raises the change requests on the documentation |
| Oliver Hughes | author, reviewer, approver | the customer's representative (KYR, the platform): writes the requirements baseline (SSS, IRD, SOW and their requirements); takes KYR's baseline as the input; closes the SRR, the PDR and the QR; approves the ICD and the PDR and QR baselines |
| Luca Romano | author | requirements and interfaces: the SRS, the ICD, the assumptions and the sources; derives the SRS from the requirements baseline |
| Emily Clarke | author | design and code: the components, the decisions, the SDD, the SUM and the API reference; files the code and the repository's documents into the space |
| Davide Conti | author | verification: the cases, the SVS and the SVR; records the release pipeline's runs at the release commit with their logs as evidence |
| James Whitfield | reviewer, author | independent reviewer: opens each review and raises the RIDs |
| Francesca Galli | approver | product assurance: approves the items, the RIDs' dispositions and the change requests; closes the CDR; approves the SRR and CDR baselines |
| Sarah Collins | config-master | configuration: freezes each review's baseline at the release commit |
<!-- /ecss:table -->

## References

An item's reference is `<path>#<anchor>`: a heading's slug (GitHub's rule) or lines `L<n>`, `L<n>-L<m>`, on the repository at
0ad84dc1; `customers/<repo>/<path>` is a customer's file at the commit `rms/customers.csv` names. A document's links are relative to the
document. Every file a reference names is in SPSCRING's space at that path: the code and the repository's documents in the inputs
drawer, the customer's files under `customers/`, this package in the documents drawer, the runs' logs in the evidence drawer.

```sh
ecss/tools/package.py check     # the CSVs, the links, the reviews, the results, every reference, the tables
ecss/tools/package.py tables    # rewrite the tables
```

## Open items

| Id | What | Closes when |
|---|---|---|
| OI-01 | Category C proposed, not confirmed by the customer | KYR's review confirms it; then declared in SPSCRING's rules |
| OI-02 | CR-001 to CR-004: the README's API contract and wrap figure, the header's thread note and @file name | the next release carries them |
| OI-03 | The platform pins 1.0.7; 1.0.8 is qualified (same code) | the platform's next train moves the pin |
| OI-04 | The format stage was skipped on the build host (no clang-format 18) | a qualification run where it is installed |
