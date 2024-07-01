git lfs uninstall
git rm --cached -r .
git reset --hard
git rm .gitattributes
git reset .
git checkout .
git lfs install
git lfs pull
