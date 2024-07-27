using System.Collections.Immutable;

using NuGetUpdater.Core.Updater;

namespace NuGetUpdater.Core;

/// <summary>
/// Updates assembly binding redirects in app.config/web.config for projects targeting .NET Framework.
/// https://learn.microsoft.com/en-us/dotnet/framework/configure-apps/redirect-assembly-versions
/// </summary>
internal static class AssemblyBindingRedirectUpdater
{
    public static async Task UpdateBindingRedirectsAsync(
        string repoRootPath,
        ImmutableArray<ProjectBuildFile> buildFiles,
        Logger logger
    )
    {
        // app.config or web.config project with assembly binding redirects; Use NuGet.exe to perform update

        var validProjectBuildFiles = buildFiles.OfType<ProjectBuildFile>()
            .Where(f => f.GetFileType() == ProjectBuildFileType.Project)
            // TODO: Filter out projects that don't target .NET Framework
            //.Where(f => f.TargetFramework?.IsNetFramework == true)
            .ToImmutableArray();

        foreach (var projectBuildFile in validProjectBuildFiles)
        {
            var projectPath = projectBuildFile.Path;
            using (new WebApplicationTargetsConditionPatcher(projectPath))
            {
                if (await BindingRedirectManager.UpdateBindingRedirectsAsync(projectBuildFile))
                {
                    logger.Log($"    Updated assembly binding redirect config for project [{projectBuildFile.RelativePath}].");
                }
            }
        }
    }
}
