@echo off
setlocal
rem ============================================================================
rem  Push this project to GitHub.
rem
rem  A workspace download does not contain the .git folder -- it is excluded
rem  from the archive -- so this script first restores the history from
rem  otms-git-backup.bundle, which sits next to the project files, and then
rem  pushes everything to GitHub. If .git is already present it is used as is.
rem
rem  Works against an empty repository (the first push) as well as one that
rem  already has commits: it asks the remote first and says which case it is in.
rem
rem  Run it from anywhere:  tools\push-to-github.bat
rem  Different repository?  tools\push-to-github.bat https://github.com/USER/REPO.git
rem ============================================================================

set "SELF=%~dp0"
cd /d "%SELF%.."
if errorlevel 1 (
  echo [X] cannot open the project folder
  exit /b 1
)

set "REMOTE=%~1"
if "%REMOTE%"=="" set "REMOTE=https://github.com/seyedmohammadsinahosseini/online-training-management-system.git"

echo ============================================================
echo   Push OTMS to GitHub
echo   folder : %CD%
echo   remote : %REMOTE%
echo ============================================================
echo.

where git >nul 2>nul
if errorlevel 1 (
  echo [X] git was not found. Install Git for Windows first, then run this again.
  exit /b 1
)

echo [1/4] looking for the project history
if exist ".git" (
  echo       .git is already here -- using it.
  goto ready
)

if not exist "otms-git-backup.bundle" (
  echo.
  echo [X] Neither .git nor otms-git-backup.bundle was found in:
  echo     %CD%
  echo.
  echo     Copy otms-git-backup.bundle from the workspace download into this
  echo     folder, then run the script again.
  exit /b 1
)

echo       no .git here -- restoring it from otms-git-backup.bundle
if exist "_otms_restore" rmdir /s /q "_otms_restore"
git clone -b main "otms-git-backup.bundle" "_otms_restore"
if errorlevel 1 (
  echo [X] could not read the bundle
  exit /b 1
)
move /y "_otms_restore\.git" ".git" >nul
if errorlevel 1 (
  echo [X] could not move the restored .git into place
  exit /b 1
)
rmdir /s /q "_otms_restore"
echo       restored.

:ready
echo.
echo [2/4] history in this folder: %CD%
git log -1 --oneline HEAD
for /f %%c in ('git rev-list --count HEAD') do echo       commits: %%c
echo.
echo       the bundle is not part of the project -- if git lists it as
echo       untracked you can delete it once the push succeeds.

echo.
echo [3/4] connecting to GitHub
git remote remove origin >nul 2>nul
git remote add origin "%REMOTE%"
git fetch origin
if errorlevel 1 (
  echo.
  echo [!] Could not reach the repository.
  echo     * It asked for a username/password: sign in with Git Credential
  echo       Manager, or use a Personal Access Token as the password.
  echo       GitHub no longer accepts account passwords over https.
  echo     * "repository not found": sign in if the repo is private, or check
  echo       that the address is still right.
  exit /b 1
)

git rev-parse --verify --quiet origin/main >nul 2>nul
if errorlevel 1 (
  echo.
  echo       the repository is empty -- this will be the first push.
  echo       all of these commits go up:
  git log --oneline HEAD
) else (
  echo.
  echo       commits that are not on GitHub yet:
  git log --oneline origin/main..HEAD
)
echo.

echo [4/4] pushing
git push -u origin HEAD:main
if errorlevel 1 (
  echo.
  echo [X] The push was rejected.
  echo     * "non-fast-forward" or "fetch first": the remote has commits this
  echo       folder does not have. Run
  echo           git pull --rebase origin main
  echo       and then this script again.
  echo     * "refusing to merge unrelated histories": the repository was
  echo       created with its own commits, for example a README added on the
  echo       website. Either delete that branch on GitHub, or run
  echo           git pull --rebase origin main --allow-unrelated-histories
  echo       Do not force-push unless you are certain.
  exit /b 1
)

echo.
echo [OK] done. Open %REMOTE%
echo.
echo This folder is now a normal git repository: edit, commit, `git push`.
echo.
exit /b 0
