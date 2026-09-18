gstart() {
  if [ -z "$1" ]; then
    echo "Error: Please provide the branch name (ex: feat/foo, fix/bar)."
    return 1
  fi
  git checkout master
  git pull origin master
  git checkout -b "$1"
}

gship() {
  local branch_name=$(git branch --show-current)
  local commit_msg=$1

  if [[ "$branch_name" == "master" ]]; then
    echo "Error: Running gship on the master branch is not allowed."
    return 1
  fi

  git add .
  git commit -m "${commit_msg:-feat: updates from dev loop}"
  git push -u origin "$branch_name"

  # Cria o PR usando os commits como corpo e abre no browser
  gh pr create --fill --web
}

gdone() {
  local current_branch=$(git branch --show-current)
  if [[ "$current_branch" == "master" ]]; then
    echo "Erro: Já se encontra na branch master."
    return 1
  fi

  # Funde o PR via CLI; gh já faz checkout para master e deleta branch local + remota
  gh pr merge --squash --delete-branch || return 1

  # Garante que a master local esteja sincronizada
  git pull origin master
}

# ============================================================
# Develop flow (feature -> develop -> master)
# ============================================================

# Start branch from develop
gstartd() {
  if [ -z "$1" ]; then
    echo "Error: Provide a branch name (ex: feat/foo, fix/bar)."
    return 1
  fi
  git checkout develop
  git pull origin develop
  git checkout -b "$1"
}

# Ship feature to develop via PR
gshipd() {
  local branch_name=$(git branch --show-current)
  local commit_msg=$1

  if [[ "$branch_name" == "develop" || "$branch_name" == "master" ]]; then
    echo "Error: Cannot run gshipd on protected branches."
    return 1
  fi

  git add .
  git commit -m "${commit_msg:-feat: integration updates}"
  git push -u origin "$branch_name"

  # PR targets develop
  gh pr create --base develop --fill --web
}

# Finalize feature into develop and cleanup
gdoned() {
  local current_branch=$(git branch --show-current)
  if [[ "$current_branch" == "develop" || "$current_branch" == "master" ]]; then
    echo "Error: You are already on a base branch."
    return 1
  fi

  # gh já faz checkout para develop (base do PR) e deleta branch local + remota
  gh pr merge --squash --delete-branch || return 1

  # Garante que o develop local esteja sincronizado
  git pull origin develop
}

# Promote develop to master
greleased() {
  git checkout master
  git pull origin master
  git checkout develop
  git pull origin develop

  # Create PR for production deployment
  gh pr create --base master --head develop --title "Release: Production Deployment $(date +%Y-%m-%d)" --body "Promoting develop branch to master for release."
}
