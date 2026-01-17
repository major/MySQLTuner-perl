## **4\. ⚙️ EXECUTION RULES & CONSTRAINTS**

### **4.1. Formal Prohibitions (Hard Constraints)**

1. **SINGLE FILE:** Spliting `mysqltuner.pl` into modules is **strictly prohibited**.
2. **NON-REGRESSION:** Deleting existing code is **prohibited** without relocation or commenting out.
3. **NO BACKWARDS COMPATIBILITY BY DEFAULT:** Do not add backwards compatibility unless specifically requested; update all downstream consumers.
4. **OPERATIONAL SILENCE:** Textual explanations/pedagogy are **proscribed** in the response. Only code blocks, commands, and technical results.
5. **TDD MANDATORY:** Use a TDD approach. _Do not assume_ that your solution is correct. Instead, _validate your solution is correct_ by first creating a test case and running the test case to _prove_ the solution is working as intended.
6. **WEB SEARCH:** Assume your world knowledge is out of date. Use your web search tool to find up-to-date docs and information.

### **4.2. Coding Guidelines**

- **SOLID Principles**: Follow Single Responsibility, Open-Closed, Liskov Substitution, Interface Segregation, and Dependency Inversion principles.
- **DRY (Don't Repeat Yourself)**: Avoid code duplication; extract common logic into reusable functions within the single file.
- **KISS (Keep It Simple, Stupid)**: Strive for simplicity. Avoid over-engineering.
- **Clean Code**: Write readable, self-documenting code with meaningful names and small functions.
- **Error Handling**: Implement robust error handling and logging. Use low-cardinality logging with stable message strings (e.g., `logger.info{id, foo}, 'Msg'`).

### **4.3. Output & Restitution Format**

1. **NO CHATTER:** No intro or conclusion sentences.
2. **CODE ONLY:** Use Search_block / replace_block format for files > 50 lines.
3. **MANDATORY PROSPECTIVE:** Each intervention must conclude with **3 technical evolution paths** to improve robustness/performance.
4. **MEMORY UPDATE:** Include the JSON MEMORY_UPDATE_PROTOCOL block at the very end.

### **4.4. Development Workflow**

1. **Validation by Proof:** All changes must be verifiable via `make test-*` or dedicated test scripts.
2. **Git Protocol:** Commit immediately after validation. Use **Conventional Commits** (feat:, fix:, chore:, docs:).
3. **Changelog:** All changes MUST be traced and documented inside `@Changelog`.
