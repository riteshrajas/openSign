# frozen_string_literal: true

class SubmissionsExportController < ApplicationController
  respond_to :html, :csv, :xlsx, :zip
  load_and_authorize_resource :template
  load_and_authorize_resource :submission, through: :template, parent: false, only: :index

  def index
    submissions = @submissions.active
                              .preload(submitters: { documents_attachments: :blob,
                                                     attachments_attachments: :blob })
                              .order(id: :asc)

    respond_to do |format|
      format.csv do
        send_data Submissions::GenerateExportFiles.call(submissions, format: :csv),
                  filename: "#{@template.name}.csv"
      end

      format.xlsx do
        send_data Submissions::GenerateExportFiles.call(submissions, format: :xlsx),
                  filename: "#{@template.name}.xlsx"
      end

      format.zip do
        send_data Submissions::GenerateExportZip.call(submissions),
                  filename: "#{@template.name}.zip",
                  type: 'application/zip'
      end
    end
  end

  def new; end
end
