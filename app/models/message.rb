# TODO: refactor kind = MessageType::... into enumerize kind or into enum kind
class Message < ApplicationRecord
  include Translation
  include Antispam

  belongs_to :from, class_name: User.name
  belongs_to :to, class_name: User.name
  belongs_to :linked, polymorphic: true, optional: true

  # отменяю проверку, т.к. могут быть уведомления по AnimeHistory
  # validates_presence_of :body

  validates :from, :to, presence: true
  validates :body,
    presence: true,
    if: -> { kind == MessageType::Private }

  before_create :check_spam_abuse,
    if: -> { kind == MessageType::Private && !from.bot? }
  after_create :send_email
  after_create :send_push_notifications

  def check_antispam
    return unless with_antispam?
    return unless id.nil?
    return if from.bot? || from.admin?
    return if kind == MessageType::Notification
    return if kind == MessageType::ClubRequest

    prior_comment = Message
      .includes(:from, :to)
      .where(from_id: from_id)
      .order(id: :desc)
      .first

    if prior_comment && prior_comment.created_at > 15.seconds.ago
      interval = 15 - (Time.zone.now.to_i - prior_comment.created_at.to_i)
      seconds = i18n_i('datetime.second', interval, :accusative)

      errors.add(
        :created_at,
        i18n_t('antispam', interval: interval, seconds: seconds)
      )
      throw :abort
    end
  end

  def new? params
    %w[
      inbox
      news
      notifications
    ].include?(params[:type]) && !read
  end

  def html_body
    BbCodes::Text.call body
  end

  def delete_by user
    if kind == MessageType::Private && to == user
      update! is_deleted_by_to: true, read: true
    else
      destroy!
    end

    self
  end

  # for rss feed
  def guid
    "message-#{id}"
  end

  def read?
    read
  end

private

  def check_spam_abuse
    throw :abort unless Messages::CheckSpamAbuse.call(self)

    unless Users::CheckHacked.call(model: self, text: body, user: from)
      throw :abort
    end
  end

  def send_email
    return unless kind == MessageType::Private
    EmailNotifier.instance.private_message self
  end

  def send_push_notifications
    return unless to.active?

    to.devices.each do |device|
      PushNotification.perform_async id, device.id
    end
  end
end
