# Creates or updates viewer-sinatra pull requests
class DeployViewerSinatraPullRequestJob
  include Sidekiq::Worker

  attr_reader :deployment
  attr_reader :github
  attr_reader :github_updater

  def initialize(github = Github.github, github_updater = GithubFileUpdater)
    @github = github
    @github_updater = github_updater
  end

  def perform(deployment)
    @deployment = deployment
    countries_json_url = 'https://raw.githubusercontent.com/' \
      'everypolitician/everypolitician-data/' \
      "#{everypolitician_data_pull_request.head.sha}/countries.json"
    updater = github_updater.new(viewer_sinatra_repo)
    updater.path = 'DATASOURCE'
    updater.branch = branch_name
    updater.update(countries_json_url)
    pull_request = create_pull_request(updater.message)
    create_deployment_status(pull_request)
  end

  private

  def existing_pull
    @existing_pull ||= github.pull_requests(viewer_sinatra_repo).find do |pull|
      pull.head.ref == branch_name
    end
  end

  def existing_pull?
    !existing_pull.nil?
  end

  def create_pull_request(message)
    if existing_pull?
      existing_pull
    else
      github.create_pull_request(
        viewer_sinatra_repo,
        'master',
        branch_name,
        message,
        pull_request_body
      )
    end
  end

  def pull_request_body
    @full_description ||= [
      "Commits:\n",
      list_of_commit_messages,
      '',
      everypolitician_data_pull_request.html_url
    ].join("\n")
  end

  def everypolitician_data_pull_request
    @pull_request ||= github.pull(
      deployment['repository']['full_name'],
      pull_request_number
    )
  end

  def list_of_commit_messages
    commits = github.pull_commits(
      deployment['repository']['full_name'],
      pull_request_number
    )
    messages = commits.map do |commit|
      commit.commit.message.lines.first.chomp
    end
    messages.map { |m| "- #{m}" }.join("\n")
  end

  def viewer_sinatra_repo
    @viewer_sinatra_repo ||= ENV.fetch('VIEWER_SINATRA_REPO')
  end

  def pull_request_number
    deployment['deployment']['payload']['pull_request_number']
  end

  def branch_name
    "everypolitician-data-pr-#{pull_request_number}"
  end

  def create_deployment_status(pull_request)
    github.create_deployment_status(
      deployment['deployment']['url'],
      'success',
      target_url: pull_request.html_url
    )
  end
end
