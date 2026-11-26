"""Checks on the ML registry, run in every pull request (no Azure needed).

1. Every YAML file follows its JSON schema (registry/schema/).
2. The rules that connect files: file names, no two use cases with the same
   repo or the same resource group.
3. Broken examples in tests/invalid/ are really refused.
"""

import json
from pathlib import Path

import pytest
import yaml
from jsonschema import Draft202012Validator

ROOT = Path(__file__).parents[1]
REGISTRY = ROOT / "registry"
INVALID = Path(__file__).parent / "invalid"

USE_CASE_FILES = sorted((REGISTRY / "ml_use_cases").glob("*.yaml"))


def validator(name: str) -> Draft202012Validator:
    schema = json.loads((REGISTRY / "schema" / f"{name}.schema.json").read_text())
    Draft202012Validator.check_schema(schema)  # the schema itself is valid
    return Draft202012Validator(schema)


def load(path: Path) -> dict:
    return yaml.safe_load(path.read_text())


def errors(name: str, data: dict) -> list[str]:
    """Readable schema errors, e.g. "predictions_table: 'x' does not match ...". """
    found = validator(name).iter_errors(data)
    return [f"{'.'.join(map(str, e.path)) or '(file)'}: {e.message}" for e in found]


def test_the_registry_is_not_empty():
    assert USE_CASE_FILES


@pytest.mark.parametrize("path", USE_CASE_FILES, ids=lambda p: p.name)
def test_use_case_file_follows_its_schema(path: Path):
    assert errors("ml_use_case", load(path)) == []


@pytest.mark.parametrize("path", USE_CASE_FILES, ids=lambda p: p.name)
def test_use_case_file_name_and_department(path: Path):
    use_case = load(path)
    assert path.stem == f"{use_case['department']}__{use_case['use_case_id']}"


def test_each_repo_belongs_to_one_use_case():
    repos = [load(p)["github_repo"].lower() for p in USE_CASE_FILES]
    assert len(repos) == len(set(repos))


def test_each_project_has_its_own_resource_group():
    """Every project gets its own resource group, rg-ml-<department>-<use_case_id>."""
    groups = [f"rg-ml-{load(p)['department']}-{load(p)['use_case_id']}" for p in USE_CASE_FILES]
    assert len(groups) == len(set(groups))


@pytest.mark.parametrize("path", USE_CASE_FILES, ids=lambda p: p.name)
def test_editor_finds_the_schema(path: Path):
    """The first line lets VS Code autocomplete and underline mistakes while typing."""
    assert path.read_text().splitlines()[0] == (
        "# yaml-language-server: $schema=../schema/ml_use_case.schema.json"
    )


@pytest.mark.parametrize("path", sorted(INVALID.glob("*.yaml")), ids=lambda p: p.name)
def test_broken_examples_are_refused(path: Path):
    assert errors("ml_use_case", load(path)), f"{path.name} should be refused by the schema"
