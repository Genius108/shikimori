class MalParsers::RefreshEntries
  include Sidekiq::Worker
  sidekiq_options(
    unique: :until_executed,
    queue: :mal_parsers
  )

  TYPES = Types::Strict::String.enum('anime', 'manga')

  def perform type, status, refresh_interval
    klass = TYPES[type].classify.constantize

    DbImport::Refresh.call(
      klass,
      ids(klass, status),
      refresh_interval.to_i.seconds
    )
  end

private

  def ids klass, status
    Animes::StatusQuery
      .call(klass.all, status)
      .order(:id)
      .pluck(:id)
  end
end
