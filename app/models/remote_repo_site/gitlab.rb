class RemoteRepoSite::Gitlab < RemoteRepoSite

  def link_to_revision(repo_url, revision_sha)
    "#{repo_url}/commits/"
  end


end
