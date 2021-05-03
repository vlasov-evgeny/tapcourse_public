class CoursePackagesController < ApplicationController
  before_action :set_course_package_group, only: [:create]
  before_action :set_course_package, only: [:show, :update, :destroy, :edit]

  def show
    authorize @course_package
  end

  def edit
    authorize @course_package
  end

  def create
    @course_package = @course_package_group.course_packages.build(course_package_params)
    authorize @course_package
    @course_package.save
    @course_package.update(course_module_unit_ids: params[:course_module_unit_ids])
    render :show
  end

  def update
    authorize @course_package
    @course_package.update(course_package_params)
    render :show
  end

  def destroy
    authorize @course_package
    @course_package.destroy
    head :no_content
  end

  def cart_data
    @course_packages = CoursePackage.where(id: params[:course_package_ids]).includes(:course_package_group)
    course_ids = @course_packages.map { |course_package| course_package.course_package_group.course_id }
    @courses = Course.where(id: course_ids)
    coupon = Coupon.find_by(code: params[:coupon_code])
    @total_price = UserCoursePackageOrder.calc_price(@course_packages, coupon)
    @discount = @course_packages.inject(0) {|sum, item| sum + item.price} - @total_price
  end

  def free_promotion
    authorize CoursePackage
    @course_packages = CoursePackage.free_packages
    course_ids = @course_packages.map { |course_package| course_package.course_package_group.course_id }
    @courses = Course.where(id: course_ids).order(:name)
    render :packages_set
  end

  def current_packages
    authorize CoursePackage
    tags = (params[:tags] || []).map(&:upcase)
    @course_packages = CoursePackage.current_packages.to_a.select do |course_package|
      (course_package.tags.map(&:upcase) & tags).length == tags.length
    end
    course_ids = @course_packages.map { |course_package| course_package.course_package_group.course_id }
    @courses = Course.where(id: course_ids).order(:name)
    render :packages_set
  end

  private

  def set_course_package_group
    @course_package_group = CoursePackageGroup.find(params[:course_package_group_id])
  end

  def set_course_package
    @course_package = CoursePackage.find(params[:id])
  end

  def course_package_params
    params.permit(:name, :description, :price, :validity_type, :active, :published, tags: [],
                  course_module_unit_ids: []).merge(validity_params)
  end

  def validity_params
    if params[:validity_type] == ValidityType::PERIOD
      validity = if params[:start_date].present? && params[:end_date].present?
                   (params[:end_date].to_date - params[:start_date].to_date).to_i
                 end
      { start_date: params[:start_date]&.to_date, validity: validity }
    elsif params[:validity_type] == ValidityType::FIXED_DAYS
      { validity: params[:validity]&.to_i, start_date: nil }
    else
      { validity: nil, start_date: nil, validity_type: nil }
    end
  end
end
