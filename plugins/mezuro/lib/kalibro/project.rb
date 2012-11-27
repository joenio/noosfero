class Kalibro::Project < Kalibro::Model

  attr_accessor :id, :name, :description

  def self.all
    response = request(:all_projects)[:project]
    response = [] if response.nil?
    response = [response] if response.is_a? (Hash) 
    response.map {|project| new project}
  end

  def self.project_of(repository_id)
    new request(:project_of, :repository_id => repository_id)[:project]
  end

end
