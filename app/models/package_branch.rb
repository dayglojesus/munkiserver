# PackageBranch records don't belong to a specific unit or environment but an specific instance can be
# scoped to return only results from a specific unit or environment
class PackageBranch < ActiveRecord::Base
  # Validations
  validates_presence_of :name
  validates_uniqueness_of :name
  
  attr_protected :id, :name
  
  attr_accessor :unit_id, :environment_id
  
  # Relationships
  has_many :install_items, :dependent => :destroy
  has_many :uninstall_items, :dependent => :destroy
  has_many :user_install_items, :dependent => :destroy
  has_many :user_uninstall_items, :dependent => :destroy
  has_many :user_allowed_items, :dependent => :destroy
  has_many :require_items, :dependent => :destroy
  has_many :update_for_items, :dependent => :destroy
  has_many :all_packages, :order => 'version desc', :class_name => "Package"
  has_one :version_tracker, :dependent => :destroy, :autosave => true
  
  before_save :require_display_name
  before_save :require_version_tracker
  
  # Returns the latest package (based on version)
  # in the package branch.  Results are scoped if scoped? returns true
  def latest(unit_member = nil)
    package(unit_member)
  end
  
  # Get all package branches mentioned by unit
  def self.unit(unit)
    Package.unit(unit).map {|p| p.package_branch }.uniq
  end
  
  # Get the latest package within a unit and environment
  def latest_where_unit_and_environment(unit,env)
    latest_where_unit(unit).where(:environment_id => env.id)
  end
  
  def latest_where_unit(unit)
    packages.where(:unit_id => unit.id).order('version desc').limit(1)
  end
  
  # Extends the functionality of the association dynamic method to
  # return only the packages that match the passed unit member
  def packages_like_unit_member(um)
    packages.where(:environment_id => um.environment_id, :unit_id => um.unit_id)
  end
  
  def packages_where_unit_and_environment(unit,environment)
    packages.where(:environment_id => environment.id, :unit_id => unit.id)
  end
  
  # Provides a scoped (if applicable) search in the Package association
  def packages
    if scoped?
      all_packages.where(:unit_id => @unit_id, :environment_id => @environment_id)
    else
      all_packages
    end
  end
  
  # Virtual attribute that retrieves the web ID from the version tracker
  # record associated to this package branch
  def version_tracker_web_id
    version_tracker.web_id unless version_tracker.nil?
  end
  
  def version_tracker_web_id=(value)
    version_tracker.web_id = value unless version_tracker.nil?
  end
  
  # True if a newer version is available in this branch
  def new_version?
    begin
      vtv < version_tracker.version
    rescue ArgumentError
      false
    end
  end
  
  # Returns latest package or package with
  # ID of arg 1 (if it exists)
  def package(unit_member = nil, id = nil)
    p = packages

    # Specify a certain ID
    p = p.where(:id => id) unless id.nil?    

    # Limiting scope to that of unit_member or current scope (defined by unit_id and environment_id)
    if unit_member != nil
      p = p.where(:environment_id => unit_member.environment_id)
      p = p.where(:unit_id => unit_member.unit_id)
    elsif scoped?
      p = p.where(:environment_id => @environment_id)
      p = p.where(:unit_id => @unit_id)
    end
    p.first
  end
  
  # Checks if version_tracker is nil and creates one if it is
  def require_version_tracker
    self.version_tracker = build_version_tracker if self.version_tracker.nil?
  end
  
  # Checks if display_name is blank, if so, it makes it the value of name
  def require_display_name
    self.display_name = self.name if self.display_name.blank?
  end
  
  # Grabs vtv from latest package
  def vtv
    latest.vtv unless latest.nil?
  end

  # Sets iVars @environment_id and @unit_id to bind this record, temporarily, to a certain scope
  def bind_to_scope(param1, param2 = nil)
    if param2.nil?
      # If only one param passed, assume it to be a unit_member
      @environment_id = param1.environment_id
      @unit_id        = param1.unit_id
    else
      # If both, assume first to be unit, second to be environment
      @unit_id        = param1.id
      @environment_id = param2.id
    end
    self.scoped?
  end
  
  # Return boolean if @unit_id and @environment_id is set
  def scoped?
    @environment_id != nil and @unit_id != nil
  end
  
  # Get the associated environment
  def environment
    Environment.find_by_id(@environment_id)
  end
  
  # Get the associated unit
  def unit
    Unit.find_by_id(@unit_id)
  end
  
  # Return the package branches available to a given unit member
  # Doesn't return an ActiveRecord::Relation (search cannot be 
  # done using only SQL)
  def self.unit_member(unit_member)
    Package.unit(unit_member.unit).environments(unit_member.environments).map { |e| e.package_branch }.uniq
  end
  
  # Get package branches with packages in a specified unit and environment
  # TO-DO Not very efficient, could be refactored
  def self.unit_and_environment(unit,environment, scope_results = true)
    pbs = Package.unit(unit).environment(environment).map {|p| p.package_branch }.uniq
    pbs.each {|pb| pb.bind_to_scope(unit,environment) if scope_results }
    pbs
  end
  
  # Overrides default to string method.  Specifies version if this package
  # isn't the latest of the current units
  def to_s(style = nil)    
    case style
      when :pretty then display_name
      else name
    end
  end
end