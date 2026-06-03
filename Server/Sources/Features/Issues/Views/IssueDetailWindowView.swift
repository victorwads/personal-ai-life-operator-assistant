import SwiftUI

struct IssueDetailWindowView: View {
    let issueId: String
    let issuesFeature: IssuesFeature

    var body: some View {
        IssueDetailScreen(
            issueId: issueId,
            issuesFeature: issuesFeature,
            relatedDataProvider: issuesFeature
        )
        .frame(minWidth: 860, minHeight: 640)
    }
}
