module RedmineUndevGit::Includes::RepoValidate
  extend ActiveSupport::Concern

  included do

    class UrlValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        regexp = /\A([\w\d\-_\.]+@[\w\d\-_\.]+:[\w\d\-_\.\/]+)|(https?|git|ssh):\/\/[\w\d\-_\.\/@:]+\z/
        unless (value =~ regexp) || File.readable_real?(value)
          record.errors.add(attribute, I18n.t(:repository_url_malformed))
        end
      end
    end

    validates :url, presence: true, url: true
    validate :url_uniqueness_check

  end

  def url_uniqueness_check
    if url.present? && url_changed? && same_url_repo = Repository.find_by_url(url)

      if same_url_repo.identifier.present?
        url_error = l(:repository_taken, project: same_url_repo.project, identifier: same_url_repo.identifier)
      else
        url_error = l(:repository_taken_without_id, project: same_url_repo.project)
      end

      errors.add(:url, url_error)
      false
    else
      true
    end
  end
end
