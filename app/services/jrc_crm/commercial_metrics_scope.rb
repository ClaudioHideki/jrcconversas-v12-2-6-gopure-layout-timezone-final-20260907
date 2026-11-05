# The same restrictive boundary used by lists and indicators. Dates refer to creation,
# not closing: an older opportunity remains visible when the user selects all time.
class JrcCrm::CommercialMetricsScope
  def self.call(account:, actor:, relation:, owner_id: nil, owner_column: :owner_id, pipeline_id: nil, start_date: nil, end_date: nil)
    if actor && !account.account_users.find_by!(user: actor).administrator?
      owner_id = actor.id
    end
    relation = relation.where(owner_column => owner_id) if owner_id.present?
    relation = if actor
                 JrcCrm::OrganizationalVisibility.new(account: account, user: actor, relation: relation).call
               else
                 JrcCrm::CorporateCoverage.new(account: account, user: actor).restrict(relation)
               end
    relation = relation.where(pipeline_id: pipeline_id) if pipeline_id.present? && relation.klass.column_names.include?('pipeline_id')
    relation = relation.where(relation.klass.arel_table[:created_at].gteq(start_date.beginning_of_day)) if start_date
    relation = relation.where(relation.klass.arel_table[:created_at].lteq(end_date.end_of_day)) if end_date
    relation = relation.where.not(status: 'archived') if relation.klass == JrcCrm::Deal
    relation
  end
end
