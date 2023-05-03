# Mod Reviewer Tools

Some tools to make it easier for modders to verify and review Mod submissions.

## Decompile.ps1

Simple script that does some magic and turns the mods you put into the `ModsToCheck` into nicely decompiled `.sln` projects with the changes from the previous approved version.

### How to use
1. Install [dnSpy](https://github.com/dnSpyEx/dnSpy) to your `%Path%`
2. Place [Mono.Cecil.dll](https://github.com/jbevain/cecil) in the root of this project (you can compile or grab it from the `\GameFolder\MelonLoader\Managed` or `\GameFolder\MelonLoader\net35`)
3. Place the mods you want to decompile on the `ModsToCheck`
4. Run `Decompile.ps1`
5. Then you should have all mods decompiled into their folder as a C# solution in the folder `Repos`

**Note:** If the mod has an approved version, there will be a commit with its decompiled code. Which means you can check the diff.

### Inner Workings
1. This script will check the folder `ModsToCheck` for mod `.dll`s and get their MelonInfoAttribute using [Mono.Cecil.dll](https://github.com/jbevain/cecil), more specifically the Name of the mod.
2. Then using the Name it will query the `https://api.cvrmg.com/v1/mods/` and if exists download the approved version of the mod and put in the `ApprovedMods` Folder.
3. Initialize a git repo for each mod.
4. If we downloaded an approved version, decompile using [dnSpy](https://github.com/dnSpyEx/dnSpy) and commit it.
5. Decompile the version to check of the mod using [dnSpy](https://github.com/dnSpyEx/dnSpy), and stage the files.


## Credits
- Thanks [Nirv-git](https://github.com/Nirv-git) for helping develop the script.
