# typed: false
# frozen_string_literal: true

require "dependabot/npm_and_yarn/package_manager"
require "dependabot/npm_and_yarn/helpers"
require "spec_helper"

RSpec.describe Dependabot::NpmAndYarn::PackageManagerHelper do
  let(:npm_lockfile) do
    instance_double(
      Dependabot::DependencyFile,
      name: "package-lock.json",
      content: <<~LOCKFILE
        {
          "name": "example-npm-project",
          "version": "1.0.0",
          "lockfileVersion": 2,
          "requires": true,
          "dependencies": {
            "lodash": {
              "version": "4.17.21",
              "resolved": "https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz",
              "integrity": "sha512-abc123"
            }
          }
        }
      LOCKFILE
    )
  end

  let(:yarn_lockfile) do
    instance_double(
      Dependabot::DependencyFile,
      name: "yarn.lock",
      content: <<~LOCKFILE
        # THIS IS AN AUTOGENERATED FILE. DO NOT EDIT THIS FILE DIRECTLY.
        # yarn lockfile v1

        lodash@^4.17.20:
          version "4.17.21"
          resolved "https://registry.yarnpkg.com/lodash/-/lodash-4.17.21.tgz#abc123"
          integrity sha512-abc123
      LOCKFILE
    )
  end

  let(:pnpm_lockfile) do
    instance_double(
      Dependabot::DependencyFile,
      name: "pnpm-lock.yaml",
      content: <<~LOCKFILE
        lockfileVersion: 5.4

        dependencies:
          lodash:
            specifier: ^4.17.20
            version: 4.17.21
            resolution:
              integrity: sha512-abc123
              tarball: https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz
      LOCKFILE
    )
  end

  let(:lockfiles) { { npm: npm_lockfile, yarn: yarn_lockfile, pnpm: pnpm_lockfile } }

  let(:register_config_files) { {} }

  let(:package_json) { { "packageManager" => "npm@7" } }
  let(:helper) { described_class.new(package_json, lockfiles, register_config_files, []) }

  before do
    allow(Dependabot::Experiments).to receive(:enabled?)
      .with(:npm_fallback_version_above_v6)
      .and_return(false)
    allow(Dependabot::Experiments).to receive(:enabled?)
      .with(:enable_shared_helpers_command_timeout)
      .and_return(true)
    allow(Dependabot::Experiments).to receive(:enabled?)
      .with(:enable_engine_version_detection)
      .and_return(true)
  end

  describe "#package_manager" do
    context "when npm lockfile exists" do
      it "returns an NpmPackageManager instance" do
        allow(Dependabot::NpmAndYarn::Helpers).to receive(:npm_version_numeric).and_return(7)
        expect(helper.package_manager).to be_a(Dependabot::NpmAndYarn::NpmPackageManager)
      end
    end

    context "when only yarn lockfile exists" do
      let(:lockfiles) { { yarn: yarn_lockfile } }

      it "returns a YarnPackageManager instance" do
        allow(Dependabot::NpmAndYarn::Helpers).to receive(:yarn_version_numeric).and_return(1)
        expect(helper.package_manager).to be_a(Dependabot::NpmAndYarn::YarnPackageManager)
      end
    end

    context "when only pnpm lockfile exists" do
      let(:lockfiles) { { pnpm: pnpm_lockfile } }

      it "returns a PNPMPackageManager instance" do
        allow(Dependabot::NpmAndYarn::Helpers).to receive(:pnpm_version_numeric).and_return(7)
        expect(helper.package_manager).to be_a(Dependabot::NpmAndYarn::PNPMPackageManager)
      end
    end

    context "when no lockfile but packageManager attribute exists" do
      let(:lockfiles) { {} }

      it "returns an NpmPackageManager instance based on the packageManager attribute" do
        expect(helper.package_manager).to be_a(Dependabot::NpmAndYarn::NpmPackageManager)
      end
    end

    context "when no lockfile and packageManager attribute, but engines field exists" do
      let(:lockfiles) { {} }
      let(:package_json) { { "engines" => { "yarn" => "1" } } }

      it "returns a YarnPackageManager instance from engines field" do
        expect(helper.package_manager).to be_a(Dependabot::NpmAndYarn::YarnPackageManager)
      end
    end

    context "when neither lockfile, packageManager, nor engines field exists" do
      let(:lockfiles) { {} }
      let(:package_json) { {} }

      it "returns default package manager" do
        expect(helper.package_manager).to be_a(Dependabot::NpmAndYarn::NpmPackageManager)
      end
    end

    context "when package manager is no longer supported" do
      subject(:package_manager) { helper.package_manager }

      let(:lockfiles) { { npm: npm_lockfile } }
      let(:package_json) { { "packageManager" => "npm@6" } }
      let(:npm_lockfile) do
        instance_double(
          Dependabot::DependencyFile,
          name: "package-lock.json",
          content: <<~LOCKFILE
            {
              "name": "example-npm-project",
              "version": "1.0.0",
              "lockfileVersion": 1,
              "requires": true,
              "dependencies": {
                "lodash": {
                  "version": "4.17.21",
                  "resolved": "https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz",
                  "integrity": "sha512-abc123"
                }
              }
            }
          LOCKFILE
        )
      end

      before do
        allow(Dependabot::Experiments).to receive(:enabled?)
          .with(:npm_fallback_version_above_v6)
          .and_return(false)
        allow(Dependabot::Experiments).to receive(:enabled?)
          .with(:enable_shared_helpers_command_timeout)
          .and_return(true)
      end

      it "returns the unsupported package manager" do
        expect(package_manager.detected_version.to_s).to eq "6"
        expect(package_manager.unsupported?).to be true
      end
    end
  end

  describe "#setup" do
    context "when lockfile specifies a deprecated version" do
      subject(:package_manager) { helper.package_manager }

      let(:lockfiles) { { npm: npm_lockfile } }
      let(:package_json) { { "packageManager" => "npm@6" } }
      let(:npm_lockfile) do
        instance_double(
          Dependabot::DependencyFile,
          name: "package-lock.json",
          content: <<~LOCKFILE
            {
              "name": "example-npm-project",
              "version": "1.0.0",
              "lockfileVersion": 1,
              "requires": true,
              "dependencies": {
                "lodash": {
                  "version": "4.17.21",
                  "resolved": "https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz",
                  "integrity": "sha512-abc123"
                }
              }
            }
          LOCKFILE
        )
      end

      before do
        allow(Dependabot::Experiments).to receive(:enabled?)
          .with(:npm_fallback_version_above_v6)
          .and_return(false)
        allow(Dependabot::Experiments).to receive(:enabled?)
          .with(:enable_shared_helpers_command_timeout)
          .and_return(true)
      end

      it "returns the deprecated version" do
        expect(package_manager.detected_version.to_s).to eq "6"
      end
    end
  end

  describe "#detect_version" do
    let(:helper) { described_class.new(package_json, lockfiles, register_config_files, []) }

    context "when packageManager field exists" do
      let(:package_json) { { "packageManager" => "npm@7.5.2" } }

      context "with a selected engine" do
        let(:package_json) do
          { "packageManager" => "npm@7.5.2", "engines" => { "npm" => ">=7.0.0 <8.0.0" } }
        end

        context "when package manager lockfile exists" do
          let(:lockfiles) { { npm: npm_lockfile } }

          it "returns the packageManager field value version over engines and lockfile" do
            expect(helper.detect_version("npm")).to eq("7.5.2")
          end
        end

        context "when package manager lockfile does not exist" do
          let(:lockfiles) { {} }

          it "returns the packageManager field value version over engines" do
            expect(helper.detect_version("npm")).to eq("7.5.2")
          end
        end
      end

      context "with multiple engines including the selected one" do
        let(:package_json) do
          {
            "packageManager" => "npm",
            "engines" => { "npm" => "8.0.0", "yarn" => "2.0.0" }
          }
        end

        context "when package manager lockfile exists" do
          let(:lockfiles) { { npm: npm_lockfile } }

          it "returns engines version over lockfile" do
            expect(helper.detect_version("npm")).to eq("8.0.0")
          end
        end

        context "when package manager lockfile does not exist" do
          let(:lockfiles) { {} }

          it "returns the engines version" do
            expect(helper.detect_version("npm")).to eq("8.0.0")
          end
        end
      end

      context "with no engine" do
        context "when package manager lockfile exists" do
          let(:lockfiles) { { npm: npm_lockfile } }

          it "returns the packageManager field version" do
            expect(helper.detect_version("npm")).to eq("7.5.2")
          end
        end

        context "when package manager lockfile does not exist" do
          let(:lockfiles) { {} }

          it "returns the packageManager field version" do
            expect(helper.detect_version("npm")).to eq("7.5.2")
          end
        end
      end

      context "with a malformed packageManager" do
        context "when package manager version is not specified correctly" do
          it "returns the nil packageManager version" do
            expect(helper.detect_version("npm^@1.2.3")).to be_nil
          end
        end
      end
    end

    context "when packageManager field does not exist" do
      let(:package_json) { {} }

      context "with engines specifying the selected package manager" do
        let(:package_json) { { "engines" => { "npm" => "8.0.0" } } }

        context "when package manager lockfile exists" do
          let(:lockfiles) { { npm: npm_lockfile } }

          it "returns engines version over lockfile" do
            expect(helper.detect_version("npm")).to eq("8.0.0")
          end
        end

        context "when package manager lockfile does not exist" do
          let(:lockfiles) { {} }

          it "returns the engines version" do
            expect(helper.detect_version("npm")).to eq("8.0.0")
          end
        end
      end

      context "with no engines and no lockfile" do
        let(:lockfiles) { {} }

        it "returns nil as no version can be detected" do
          expect(helper.detect_version("npm")).to be_nil
        end
      end

      context "with no engines and a lockfile for the selected package manager" do
        let(:lockfiles) { { npm: npm_lockfile } }

        it "returns the version inferred from the lockfile" do
          expect(helper.detect_version("npm")).to eq("8")
        end
      end

      context "with no engines and a lockfile for a different package manager" do
        let(:lockfiles) { { yarn: yarn_lockfile } }

        it "returns nil as no version can be detected for the selected package manager" do
          expect(helper.detect_version("npm")).to be_nil
        end
      end

      context "with no engines and multiple lockfiles" do
        let(:lockfiles) { { npm: npm_lockfile, yarn: yarn_lockfile } }

        it "returns the version inferred from the lockfile matching the selected package manager" do
          expect(helper.detect_version("npm")).to eq("8")
        end
      end
    end
  end

  describe "#installed_version" do
    before do
      allow(Dependabot::NpmAndYarn::Helpers).to receive_messages(
        npm_version_numeric: 7,
        yarn_version_numeric: 1,
        pnpm_version_numeric: 7
      )
    end

    context "when the installed version matches the expected format" do
      before do
        allow(Dependabot::SharedHelpers).to receive(:run_shell_command)
          .with("corepack npm -v", fingerprint: "corepack npm -v").and_return("7.5.2")
      end

      it "returns the raw installed version" do
        expect(helper.installed_version("npm")).to eq("7.5.2")
      end
    end

    context "when the installed version not found returns inferred version" do
      before do
        allow(Dependabot::SharedHelpers).to receive(:run_shell_command)
          .with("corepack yarn -v", fingerprint: "corepack yarn -v")
          .and_return("1")
        allow(Dependabot::NpmAndYarn::Helpers).to receive(:yarn_version_numeric).and_return(1)
      end

      it "falls back to the lockfile version" do
        expect(helper.installed_version("yarn")).to eq("1")
        # Verify memoization
        expect(helper.instance_variable_get(:@installed_versions)["yarn"]).to eq("1")
      end
    end

    context "when memoization is in effect" do
      before do
        allow(Dependabot::SharedHelpers).to receive(:run_shell_command)
          .with("corepack pnpm -v", fingerprint: "corepack pnpm -v").and_return("7.1.0")
        # Pre-cache the result
        helper.installed_version("pnpm")
      end

      it "does not re-run the shell command and uses the cached version" do
        expect(Dependabot::SharedHelpers).not_to receive(:run_shell_command)
          .with("corepack pnpm -v", fingerprint: "corepack pnpm -v")
        expect(helper.installed_version("pnpm")).to eq("7.1.0")
      end
    end
  end

  describe "#find_engine_constraints_as_requirement" do
    context "when the engines field contains valid constraints" do
      let(:package_json) do
        {
          "name" => "example",
          "version" => "1.0.0",
          "engines" => {
            "npm" => ">=6.0.0 <8.0.0",
            "yarn" => ">=1.22.0 <2.0.0",
            "pnpm" => "7.5.0"
          }
        }
      end

      it "returns a requirement for npm with the correct constraints" do
        requirement = helper.find_engine_constraints_as_requirement("npm")
        expect(requirement).to be_a(Dependabot::NpmAndYarn::Requirement)
        expect(requirement.constraints).to eq([">= 6.0.0", "< 8.0.0"])
      end

      it "returns a requirement for yarn with the correct constraints" do
        requirement = helper.find_engine_constraints_as_requirement("yarn")
        expect(requirement).to be_a(Dependabot::NpmAndYarn::Requirement)
        expect(requirement.constraints).to eq([">= 1.22.0", "< 2.0.0"])
      end

      it "returns a requirement for pnpm with the correct fixed version" do
        requirement = helper.find_engine_constraints_as_requirement("pnpm")
        expect(requirement).to be_a(Dependabot::NpmAndYarn::Requirement)
        expect(requirement.constraints).to eq(["= 7.5.0"])
      end

      context "when package manager lockfile does not exist" do
        let(:lockfiles) { {} }

        it "returns a requirement for npm with the correct constraints" do
          # NOTE: This is a regression test for a previous bug where calling
          # helper.package_manager will mutate helper's internal state and break
          # subsequent calls to helper.find_engine_constraints_as_requirement.
          expect(helper.package_manager).to be_a(Dependabot::NpmAndYarn::NpmPackageManager)

          requirement = helper.find_engine_constraints_as_requirement("npm")
          expect(requirement).to be_a(Dependabot::NpmAndYarn::Requirement)
          expect(requirement.constraints).to eq([">= 6.0.0", "< 8.0.0"])
        end
      end
    end

    context "when the engines field does not contain the specified package manager" do
      it "returns nil" do
        requirement = helper.find_engine_constraints_as_requirement("nonexistent")
        expect(requirement).to be_nil
      end
    end

    context "when the engines field is empty" do
      let(:package_json) { { "name" => "example", "version" => "1.0.0" } }

      it "returns nil" do
        requirement = helper.find_engine_constraints_as_requirement("npm")
        expect(requirement).to be_nil
      end
    end

    context "when the engines field contains an invalid constraint" do
      let(:package_json) do
        {
          "name" => "example",
          "version" => "1.0.0",
          "engines" => {
            "npm" => "invalid"
          }
        }
      end

      it "logs an error and returns nil" do
        expect(Dependabot.logger).to receive(:warn).with(/Unrecognized constraint format for npm: invalid/)
        requirement = helper.find_engine_constraints_as_requirement("npm")
        expect(requirement).to be_nil
      end
    end

    context "when constraints are valid" do
      let(:package_json) { { "engines" => { "npm" => ">= 6.0.0 < 8.0.0" } } }

      it "returns a requirement object with correct constraints" do
        requirement = helper.find_engine_constraints_as_requirement("npm")
        expect(requirement).to be_a(Dependabot::NpmAndYarn::Requirement)
        expect(requirement.constraints).to eq([">= 6.0.0", "< 8.0.0"])
      end
    end

    context "when constraints are empty" do
      let(:package_json) { { "engines" => { "npm" => "" } } }

      it "returns nil" do
        requirement = helper.find_engine_constraints_as_requirement("npm")
        expect(requirement).to be_nil
      end
    end

    context "when constraints are nil" do
      let(:package_json) { { "engines" => {} } }

      it "returns nil" do
        requirement = helper.find_engine_constraints_as_requirement("npm")
        expect(requirement).to be_nil
      end
    end

    context "when constraints contain an invalid format" do
      let(:package_json) { { "engines" => { "npm" => "invalid-constraint" } } }

      it "logs a warning and returns nil" do
        expect(Dependabot.logger).to receive(:warn).with(/Unrecognized constraint format for npm/)
        requirement = helper.find_engine_constraints_as_requirement("npm")
        expect(requirement).to be_nil
      end
    end
  end
end
