class Webinar < ApplicationRecord
  include UnitContent
  include EditorJsContent
  has_one :course_module_unit, as: :unit_content
  accepts_nested_attributes_for :course_module_unit
  has_many :messages, as: :target, autosave: true, dependent: :destroy
  has_many_attached :attachments
  has_enumeration_for :state, with: WebinarState, create_helpers: true, required: true

  before_validation :init

  attr_accessor :original_id

  after_create_commit do |webinar_unit|
    if original_id.present?
      ClipboardWorker.perform_async(ClipboardWorker::COPY_WEBINAR_UNIT_ATTACHMENTS, {
          copy_id: webinar_unit.id,
          original_id: original_id
      })
    end
  end

  def check_complete_payload(payload)
    return true if codeword.blank?

    codeword.strip.chomp.casecmp?(payload[:codeword].strip.chomp)
  end

  def youtube_id
    Utils.youtube_id(url)
  end

  def create_copy
    deep_clone(preprocessor: ->(_original, kopy) {
      kopy.course_module_unit = nil
    }) do |original, kopy|
      kopy.original_id = original.id if kopy.is_a?(Webinar)
    end
  end

  def finish_copying(original)
    copy_attachments(original)
    update_copied_attachments_links!
  end

  private

  def init
    self.state ||= WebinarState::PLANNED
  end
end
