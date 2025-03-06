# Measurement results from periodic tasks example

| Config       | Cycles| Instructions |
| :-:          | :-:   | :-:          |
| SW           | 68853 | 58370        |
| HWS          | 67715 | 56610        |
| PCS2         | 57697 | 46426        |
| PCS4         | 54577 | 43426        |
| PCS4-inline* | 50524 | 41640        |

* Heksa: I made the ISRs as fully inline. This measurement is not comparable to
  anything but the PCS4 but can give an idea of how much overhead is caused by
  the extra jump in proc-macro handlers.
