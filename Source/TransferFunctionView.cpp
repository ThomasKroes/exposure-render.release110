/*
	Copyright (c) 2011, T. Kroes <t.kroes@tudelft.nl>
	All rights reserved.

	Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

	- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
	- Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
	- Neither the name of the <ORGANIZATION> nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
	
	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#include "Stable.h"

#include "TransferFunction.h"
#include "TransferFunctionView.h"
#include "NodeItem.h"
#include "RenderThread.h"

QTFView::QTFView(QWidget* pParent /*= NULL*/) :
	QGraphicsView(pParent),
	m_Margin(25, 15, 10, 15),
	m_CanvasRectangle(),
	m_Scene(),
	m_Background(NULL),
	m_Grid(NULL),
	m_HistogramItem(NULL),
	m_TransferFunctionItem(NULL)
{
	// Styling
 	setFrameShadow(Sunken);
 	setFrameShape(NoFrame);

	// Never show scrollbars
	setVerticalScrollBarPolicy(Qt::ScrollBarAlwaysOff);
	setHorizontalScrollBarPolicy(Qt::ScrollBarAlwaysOff);

	setBackgroundBrush(QBrush(QColor(240, 240, 240)));

	setScene(&m_Scene);

	// Turn anti-aliasing on
	setRenderHint(QPainter::Antialiasing);

	m_TransferFunctionItem.SetTransferFunction(&gTransferFunction);

	m_Background.setEnabled(false);
	m_Grid.setEnabled(false);
	m_HistogramItem.setEnabled(false);
	m_TransferFunctionItem.setEnabled(false);

	m_Scene.addItem(&m_Background);
	m_Scene.addItem(&m_Grid);
 	m_Scene.addItem(&m_HistogramItem);
	m_Scene.addItem(&m_TransferFunctionItem);

	m_Background.setZValue(0);
	m_Grid.setZValue(100);
	m_HistogramItem.setZValue(200);
	m_TransferFunctionItem.setZValue(300);

 	m_Background.setTransform(QTransform::fromTranslate(m_Margin.GetLeft(), m_Margin.GetTop()), true);
	m_Grid.setTransform(QTransform::fromTranslate(m_Margin.GetLeft(), m_Margin.GetTop()), true);
 	m_HistogramItem.setTransform(QTransform::fromTranslate(m_Margin.GetLeft(), m_Margin.GetTop()), true);
	m_TransferFunctionItem.setTransform(QTransform::fromTranslate(m_Margin.GetLeft(), m_Margin.GetTop()), true);

	QObject::connect(&gTransferFunction, SIGNAL(Changed()), this, SLOT(OnTransferFunctionChanged()));
	QObject::connect(&gTransferFunction, SIGNAL(SelectionChanged(QNode*)), this, SLOT(OnNodeSelectionChanged(QNode*)));
}

void QTFView::resizeEvent(QResizeEvent* pResizeEvent)
{
	QGraphicsView::resizeEvent(pResizeEvent);

	m_CanvasRectangle = rect();

	m_CanvasRectangle.adjust(m_Margin.GetLeft(),  m_Margin.GetTop(), -m_Margin.GetRight(), -m_Margin.GetBottom());

	m_Background.setRect(m_CanvasRectangle);
	m_Grid.setRect(m_CanvasRectangle);
	m_HistogramItem.setRect(m_CanvasRectangle);
	m_TransferFunctionItem.setRect(m_CanvasRectangle);

	m_HistogramItem.Update();
	m_TransferFunctionItem.Update();

	setSceneRect(rect());
}

void QTFView::SetHistogram(const QHistogram& Histogram)
{
	m_HistogramItem.SetHistogram(Histogram);
}

void QTFView::OnTransferFunctionChanged(void)
{
	m_TransferFunctionItem.Update();
}

void QTFView::OnNodeSelectionChanged(QNode* pNode)
{
	// Deselect all nodes
	for (int i = 0; i < m_TransferFunctionItem.m_Nodes.size(); i++)
		m_TransferFunctionItem.m_Nodes[i]->setSelected(false);

	if (pNode)
	{
		for (int i = 0; i < m_TransferFunctionItem.m_Nodes.size(); i++)
		{
			if (m_TransferFunctionItem.m_Nodes[i]->m_pNode->GetID() == pNode->GetID())
				m_TransferFunctionItem.m_Nodes[i]->setSelected(true);
		}
	}
}

void QTFView::setEnabled(bool Enabled)
{
	QGraphicsView::setEnabled(Enabled);

	m_Background.setEnabled(Enabled);
	m_Grid.setEnabled(Enabled);
	m_HistogramItem.setEnabled(Enabled);
	m_TransferFunctionItem.setEnabled(Enabled);
}

void QTFView::mousePressEvent(QMouseEvent* pEvent)
{
	QGraphicsView::mousePressEvent(pEvent);

	// Get node item under cursor
	//TODO check if the given transform is apporpiate -wouter-
	QNodeItem* pNodeItem = dynamic_cast<QNodeItem*>(scene()->itemAt(pEvent->localPos() - QPointF(rect().left(), rect().top()), QGraphicsView::transform()));

	if (!pNodeItem)
	{
		// Add a new node if the user clicked the left button
		if (pEvent->button() == Qt::LeftButton && m_CanvasRectangle.contains(pEvent->pos()))
		{
			// Convert picked position to transfer function coordinates
			QPointF TransferFunctionPoint((pEvent->localPos().x() - m_Margin.GetLeft()) / m_CanvasRectangle.width(), (pEvent->localPos().y() - m_Margin.GetTop()) / m_CanvasRectangle.height());

			// Create new transfer function node
			QNode NewNode(&gTransferFunction, TransferFunctionPoint.x(), 1.0f - TransferFunctionPoint.y(), QColor::fromHsl((int)(((float)rand() / (float)RAND_MAX) * 359.0f), 150, 150), QColor::fromHsl(0, 0, 50), QColor::fromHsl(0, 0, 0));

			// Add to node list
			gTransferFunction.AddNode(NewNode);

			// Redraw
			m_TransferFunctionItem.Update();
		}

		if (pEvent->button() == Qt::RightButton)
		{
			// Other wise no node selection
			gTransferFunction.SetSelectedNode((QNode*)NULL);
		}
	}
	else
	{
		if (pEvent->button() == Qt::LeftButton)
		{
			gTransferFunction.SetSelectedNode(pNodeItem->m_pNode);
		}
		else if (pEvent->button() == Qt::RightButton)
		{
			const int Index = gTransferFunction.GetNodes().indexOf(*pNodeItem->m_pNode);

			// Remove transfer function node if not the first or last node
			if (Index != 0 && Index != gTransferFunction.GetNodes().size() - 1)
				gTransferFunction.RemoveNode(pNodeItem->m_pNode);
		}
	}
}