# Ring-Test Playbook — Java / JVM

## Runner

Wrapper first: `./gradlew test` or `mvn -q test` (per stack-detect `pkg=`).
Single class: `./gradlew test --tests 'ClassName'` / `mvn -q test -Dtest=ClassName`.
Failure details live in `build/reports/tests/` (Gradle) or
`target/surefire-reports/` (Maven) — read them; console output is truncated.

## Conventions

- Tests in `src/test/java/...` mirroring the source package.
- JUnit 5 (`@Test`, `@ParameterizedTest` for input matrices) unless the repo
  is visibly JUnit 4 (`@RunWith`) — match what's there.
- Assertions: use what the repo uses (AssertJ `assertThat` if present in the
  build file, else JUnit's `assertEquals`/`assertThrows`). Do not add AssertJ
  to a project that doesn't have it.
- Names: method names describe behavior — `returnsEmptyListWhenNoItemsMatch()`
  or `@DisplayName` if the repo uses them.
- Exceptions asserted specifically: `assertThrows(SpecificException.class, ...)`
  and assert on the message only if the message is the contract.
- Mock at boundaries with Mockito ONLY if it's already a dependency;
  hand-rolled fakes otherwise. Never mock the unit under test.
- Spring Boot: prefer plain unit tests over `@SpringBootTest` for logic —
  the container boot belongs to wield/integration, not ring-test.

## What to cover per behavior

1. Happy path with realistic input.
2. Edge: null (and `Optional.empty()`), empty collections, boundary values.
3. Error path: invalid input → the documented exception, asserted specifically.

## Flakes

Rerun the failing class alone. Pass-on-rerun = FLAKY finding — look for
static state, time, and test-order dependence (`@TestMethodOrder` misuse).
Never add `@Disabled` or retry plugins to get green.
