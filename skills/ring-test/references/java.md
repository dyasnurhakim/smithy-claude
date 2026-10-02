# Ring-Test Playbook — Java / JVM

## Runner

Wrapper first: `./gradlew test` or `mvn -q test` (per stack-detect `pkg=`).
One class: `./gradlew test --tests 'ClassName'` / `mvn -q test -Dtest=ClassName`.
Failure details are in `build/reports/tests/` (Gradle) or
`target/surefire-reports/` (Maven) — read them; the console output is cut short.

## Conventions

- Tests go in `src/test/java/...`, in the same package path as the source.
- JUnit 5 (`@Test`, `@ParameterizedTest` for input tables) unless the repo
  clearly uses JUnit 4 (`@RunWith`) — match what is there.
- Assertions: use what the repo uses (AssertJ `assertThat` if it is in the
  build file, else JUnit's `assertEquals` / `assertThrows`). Do not add
  AssertJ to a project that does not have it.
- Names: method names say the behavior — `returnsEmptyListWhenNoItemsMatch()`,
  or `@DisplayName` if the repo uses it.
- Check exceptions by type: `assertThrows(SpecificException.class, ...)`;
  check the message only if the message is the contract.
- Mock at boundaries with Mockito ONLY if it is already a dependency;
  otherwise hand-written fakes. Never mock the unit under test.
- Spring Boot: prefer plain unit tests over `@SpringBootTest` for logic —
  booting the container belongs to wield / integration tests, not ring-test.

## What to cover per behavior

1. Happy path with realistic input.
2. Edges: null (and `Optional.empty()`), empty collections, boundary values.
3. Error path: bad input → the documented exception, checked by type.

## Flakes

Rerun the failing class alone. Passes on the rerun = a FLAKY finding — look
for static state, time, and test-order dependence (`@TestMethodOrder` misuse).
Never add `@Disabled` or retry plugins to get green.
