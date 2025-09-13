import { LightningElement, wire, track } from 'lwc';
import getOrderPage from '@salesforce/apex/GLW_OrderController.getOrderPage';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { deleteRecord } from 'lightning/uiRecordApi';

export default class GlwOrderList extends LightningElement {
    pageSize = 15;
    pageNumber = 1;
    totalRecords = 0;
    totalPages = 1;
    wiredResult;
    @track rows = [];
    searchTerm = '';
    searchDebounce;
    showDetail = false;
    selectedOrderId;

    columns = [];

    @wire(getOrderPage, { pageSize: '$pageSize', pageNumber: '$pageNumber', searchTerm: '$searchTerm' })
    wiredOrders(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.totalRecords = data.total || 0;
            this.totalPages = Math.max(1, Math.ceil(this.totalRecords / this.pageSize));
            const list = data.records || [];
            this.rows = list.map(o => ({
                id: o.Id,
                name: o.Name,
                customerName: this.computeCustomerName(o.GLW_Customer__r),
                customerCity: o.GLW_Customer__r ? o.GLW_Customer__r.GLW_City__c : null,
                orderDate: o.GLW_OrderDate__c,
                total: o.GLW_Total__c,
                overdue: o.GLW_FlagOverdue__c,
                weather: o.GLW_WeatherDescription__c,
                weatherTemp: o.GLW_WeatherTemperature__c,
                weatherUpdated: o.GLW_WeatherLastUpdated__c,
                createdDate: o.CreatedDate
            }));
        } else if (error) {
            // Simple console error; enhance as needed
            // eslint-disable-next-line no-console
            console.error('Error loading orders', error);
        }
    }

    computeCustomerName(cust) {
        if (!cust) return null;
        const parts = [];
        if (cust.GLW_FirstName__c) parts.push(cust.GLW_FirstName__c);
        if (cust.GLW_LastName__c) parts.push(cust.GLW_LastName__c);
        return parts.join(' ');
    }

    async refresh() {
        if (this.wiredResult) {
            await refreshApex(this.wiredResult);
        }
    }

    handlePrev() {
        if (this.pageNumber > 1) {
            this.pageNumber -= 1;
        }
    }

    handleNext() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber += 1;
        }
    }

    get isFirstPage() {
        return this.pageNumber <= 1;
    }

    get isLastPage() {
        return this.pageNumber >= this.totalPages;
    }

    handleSearchChange(event) {
        const val = (event.target && event.target.value) ? event.target.value.trim() : '';
        window.clearTimeout(this.searchDebounce);
        this.searchDebounce = setTimeout(() => {
            this.searchTerm = val;
            this.pageNumber = 1; // reset to first page on new search
        }, 300);
    }

    // Row action handler to show detail
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'view') {
            this.selectedOrderId = row.id;
            this.showDetail = true;
        }
    }

    closeDetail() {
        this.showDetail = false;
        this.selectedOrderId = undefined;
    }

    // Build columns once component is constructed to safely reference instance methods
    connectedCallback() {
        this.columns = [
            { label: 'Order Name', fieldName: 'name', type: 'text' },
            { label: 'Customer', fieldName: 'customerName', type: 'text' },
            { label: 'City', fieldName: 'customerCity', type: 'text' },
            { label: 'Order Date', fieldName: 'orderDate', type: 'date' },
            { label: 'Total', fieldName: 'total', type: 'currency', typeAttributes: { currencyCode: 'USD' } },
            { label: 'Overdue', fieldName: 'overdue', type: 'boolean' },
            { label: 'Weather', fieldName: 'weather', type: 'text' },
            { label: 'Temp (°C)', fieldName: 'weatherTemp', type: 'number', typeAttributes: { minimumIntegerDigits: 1, maximumFractionDigits: 2 } },
            { label: 'Last Updated', fieldName: 'weatherUpdated', type: 'date' },
            { type: 'action', typeAttributes: { rowActions: this.getRowActions } }
        ];
    }

    getRowActions(row, doneCallback) {
        const actions = [
            { label: 'View Details', name: 'view' },
            { label: 'Edit', name: 'edit' },
            { label: 'Delete', name: 'delete' }
        ];
        doneCallback(actions);
    }

    // Create/Edit/Delete
    showCreate = false;
    showEdit = false;

    openNew() {
        this.showCreate = true;
    }

    closeCreate() {
        this.showCreate = false;
    }

    openEdit(orderId) {
        this.selectedOrderId = orderId;
        this.showEdit = true;
    }

    closeEdit() {
        this.showEdit = false;
        this.selectedOrderId = undefined;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'view') {
            this.selectedOrderId = row.id;
            this.showDetail = true;
        } else if (actionName === 'edit') {
            this.openEdit(row.id);
        } else if (actionName === 'delete') {
            this.deleteOrder(row.id);
        }
    }

    async deleteOrder(id) {
        try {
            // basic confirm
            // eslint-disable-next-line no-alert
            const ok = window.confirm('Delete this order?');
            if (!ok) return;
            await deleteRecord(id);
            this.dispatchEvent(new ShowToastEvent({ title: 'Deleted', message: 'Order deleted', variant: 'success' }));
            await this.refresh();
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error deleting', message: (e && e.body && e.body.message) ? e.body.message : 'Unknown error', variant: 'error' }));
        }
    }

    async handleCreateSuccess() {
        this.closeCreate();
        this.dispatchEvent(new ShowToastEvent({ title: 'Created', message: 'Order created', variant: 'success' }));
        await this.refresh();
    }

    async handleEditSuccess() {
        this.closeEdit();
        this.dispatchEvent(new ShowToastEvent({ title: 'Updated', message: 'Order updated', variant: 'success' }));
        await this.refresh();
    }
}
